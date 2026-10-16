package com.max.salao.release;

import com.max.salao.release.AppReleaseDtos.ReleaseResponse;
import com.max.salao.release.AppReleaseDtos.VersionResponse;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Atualização dos apps fora da loja: consulta de versão, download do APK e publicação pelo CI. */
@RestController
public class AppReleaseController {

    private static final MediaType APK = MediaType.parseMediaType("application/vnd.android.package-archive");

    private final AppReleaseService service;

    public AppReleaseController(AppReleaseService service) {
        this.service = service;
    }

    @GetMapping("/api/app/version")
    public VersionResponse version(@RequestParam String app) {
        return service.latestVersion(MobileApp.parse(app));
    }

    @GetMapping("/api/app/download/latest")
    public ResponseEntity<Resource> downloadLatest(@RequestParam String app) {
        return download(service.latest(MobileApp.parse(app)));
    }

    @GetMapping("/api/app/download/{id}")
    public ResponseEntity<Resource> downloadById(@PathVariable Long id) {
        return download(service.get(id));
    }

    /** Chamado pelo workflow mobile-release com o header {@code X-Deploy-Token}. */
    @PostMapping(value = "/api/app/releases/deploy", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ReleaseResponse deploy(@RequestHeader(value = "X-Deploy-Token", required = false) String token,
                                  @RequestPart("file") MultipartFile file,
                                  @RequestParam String app,
                                  @RequestParam String versionName,
                                  @RequestParam int versionCode,
                                  @RequestParam(required = false) String releaseNotes,
                                  @RequestParam(defaultValue = "false") boolean forceUpdate) {
        service.checkDeployToken(token);
        return service.publish(MobileApp.parse(app), file, versionName, versionCode, releaseNotes, forceUpdate);
    }

    private ResponseEntity<Resource> download(AppRelease release) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(release.getFileName()).build().toString())
                .contentType(APK)
                .contentLength(release.getFileSizeBytes())
                .body(new FileSystemResource(service.file(release)));
    }
}
