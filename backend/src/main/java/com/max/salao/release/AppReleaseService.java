package com.max.salao.release;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;

import com.max.salao.release.AppReleaseDtos.ReleaseResponse;
import com.max.salao.release.AppReleaseDtos.VersionResponse;
import com.max.salao.shared.NotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

/** Publicação e download dos APKs distribuídos fora da loja (canal "direct" dos apps). */
@Service
public class AppReleaseService {

    private static final int MAX_NOTES = 2000;

    private final AppReleaseRepository repository;
    private final AppReleaseProperties props;

    public AppReleaseService(AppReleaseRepository repository, AppReleaseProperties props) {
        this.repository = repository;
        this.props = props;
    }

    @Transactional(readOnly = true)
    public VersionResponse latestVersion(MobileApp app) {
        AppRelease r = latest(app);
        return new VersionResponse(r.getVersionName(), r.getVersionCode(), downloadUrl(r), r.getReleaseNotes(),
                r.isForceUpdate(), r.getSha256());
    }

    @Transactional(readOnly = true)
    public AppRelease latest(MobileApp app) {
        return repository.findFirstByAppOrderByVersionCodeDesc(app.id())
                .orElseThrow(() -> new NotFoundException("Nenhuma versão publicada"));
    }

    @Transactional(readOnly = true)
    public AppRelease get(Long id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Versão não encontrada"));
    }

    /** {@code app = null} lista todos. */
    @Transactional(readOnly = true)
    public List<ReleaseResponse> list(MobileApp app) {
        List<AppRelease> releases = app == null
                ? repository.findAllByOrderByAppAscVersionCodeDesc()
                : repository.findByAppOrderByVersionCodeDesc(app.id());
        return releases.stream().map(this::toResponse).toList();
    }

    public Path file(AppRelease release) {
        Path path = storagePath(release.getFileName());
        if (!Files.isRegularFile(path)) {
            throw new NotFoundException("Arquivo do APK não encontrado no servidor");
        }
        return path;
    }

    public void checkDeployToken(String token) {
        String expected = props.deployToken();
        if (expected.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Deploy de APK não configurado no servidor");
        }
        if (token == null || !MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                token.getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Token de deploy inválido");
        }
    }

    @Transactional
    public ReleaseResponse publish(MobileApp app, MultipartFile file, String versionName, int versionCode,
                                   String releaseNotes, boolean forceUpdate) {
        if (versionName == null || versionName.isBlank() || versionName.trim().length() > 32) {
            throw badRequest("versionName é obrigatório (até 32 caracteres)");
        }
        if (versionCode < 1) {
            throw badRequest("versionCode inválido");
        }
        validateApk(file);
        if (repository.existsByAppAndVersionCode(app.id(), versionCode)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "versionCode " + versionCode + " já publicado");
        }

        Path target = storagePath("salao-max-" + app.id() + "-v" + versionCode + ".apk");
        String sha256;
        long size;
        try {
            Files.createDirectories(target.getParent());
            file.transferTo(target);
            sha256 = sha256(target);
            size = Files.size(target);
        } catch (IOException ex) {
            deleteQuietly(target);
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Falha ao salvar o APK");
        }

        // Se a versão atual era obrigatória, a nova continua sendo (quem está atrás ainda precisa atualizar).
        boolean previousForce = repository.findFirstByAppOrderByVersionCodeDesc(app.id())
                .filter(prev -> prev.getVersionCode() < versionCode)
                .map(AppRelease::isForceUpdate)
                .orElse(false);

        AppRelease release = new AppRelease();
        release.setApp(app.id());
        release.setVersionName(versionName.trim());
        release.setVersionCode(versionCode);
        release.setFileName(target.getFileName().toString());
        release.setFileSizeBytes(size);
        release.setSha256(sha256);
        release.setReleaseNotes(notes(releaseNotes));
        release.setForceUpdate(forceUpdate || previousForce);
        release = repository.save(release);

        if (release.isForceUpdate()) {
            clearForceOnOthers(release);
        }
        prune(app);
        return toResponse(release);
    }

    @Transactional
    public ReleaseResponse setForceUpdate(Long id, boolean forceUpdate) {
        AppRelease release = get(id);
        release.setForceUpdate(forceUpdate);
        if (forceUpdate) {
            clearForceOnOthers(release);
        }
        return toResponse(release);
    }

    /** Só uma versão por app fica marcada como obrigatória. */
    private void clearForceOnOthers(AppRelease keep) {
        repository.findByAppOrderByVersionCodeDesc(keep.getApp()).stream()
                .filter(r -> !r.getId().equals(keep.getId()) && r.isForceUpdate())
                .forEach(r -> r.setForceUpdate(false));
    }

    /** Mantém só as N versões mais novas do app, no banco e no disco. */
    private void prune(MobileApp app) {
        List<AppRelease> all = repository.findByAppOrderByVersionCodeDesc(app.id());
        for (AppRelease old : all.subList(Math.min(props.maxRetained(), all.size()), all.size())) {
            repository.delete(old);
            deleteQuietly(storagePath(old.getFileName()));
        }
    }

    private static void validateApk(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw badRequest("Envie o arquivo .apk");
        }
        String name = file.getOriginalFilename();
        if (name == null || !name.toLowerCase().endsWith(".apk")) {
            throw badRequest("Envie um arquivo .apk");
        }
        // APK é um ZIP: começa com "PK"
        byte[] magic;
        try (InputStream in = file.getInputStream()) {
            magic = in.readNBytes(2);
        } catch (IOException ex) {
            throw badRequest("Não foi possível ler o arquivo enviado");
        }
        if (magic.length < 2 || magic[0] != 'P' || magic[1] != 'K') {
            throw badRequest("O arquivo não parece um APK válido");
        }
    }

    private Path storagePath(String fileName) {
        Path dir = Path.of(props.storagePath()).toAbsolutePath().normalize();
        Path path = dir.resolve(fileName).normalize();
        if (!path.getParent().equals(dir)) {
            throw badRequest("Nome de arquivo inválido");
        }
        return path;
    }

    private String downloadUrl(AppRelease r) {
        return props.publicBaseUrl() + "/api/app/download/" + r.getId();
    }

    private ReleaseResponse toResponse(AppRelease r) {
        return new ReleaseResponse(r.getId(), r.getApp(), r.getVersionName(), r.getVersionCode(), r.getFileName(),
                r.getFileSizeBytes(), r.getSha256(), r.getReleaseNotes(), r.isForceUpdate(), downloadUrl(r),
                r.getCreatedAt());
    }

    private static String notes(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String notes = raw.trim();
        return notes.length() <= MAX_NOTES ? notes : notes.substring(0, MAX_NOTES);
    }

    private static String sha256(Path path) throws IOException {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException(ex);
        }
        try (InputStream in = new DigestInputStream(Files.newInputStream(path), digest)) {
            in.transferTo(OutputStream.nullOutputStream());
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException ignored) {
            // arquivo órfão não impede a operação
        }
    }

    private static ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
