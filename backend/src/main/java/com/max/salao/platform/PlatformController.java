package com.max.salao.platform;

import java.util.List;

import com.max.salao.platform.PlatformDtos.BlockRequest;
import com.max.salao.platform.PlatformDtos.PlatformUser;
import com.max.salao.platform.PlatformDtos.SalonSummary;
import com.max.salao.release.AppReleaseDtos.ForceUpdateRequest;
import com.max.salao.release.AppReleaseDtos.ReleaseResponse;
import com.max.salao.release.AppReleaseService;
import com.max.salao.release.MobileApp;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Painel do administrador da plataforma (papel PLATFORM_ADMIN, ver SecurityConfig). */
@RestController
@RequestMapping("/api/platform")
public class PlatformController {

    private final PlatformService service;
    private final AppReleaseService releases;

    public PlatformController(PlatformService service, AppReleaseService releases) {
        this.service = service;
        this.releases = releases;
    }

    @GetMapping("/salons")
    public List<SalonSummary> salons(@RequestParam(required = false) String q) {
        return service.listSalons(q);
    }

    @PostMapping("/salons/{id}/block")
    public SalonSummary blockSalon(@PathVariable Long id, @Valid @RequestBody BlockRequest req) {
        return service.blockSalon(id, req.reason());
    }

    @PostMapping("/salons/{id}/unblock")
    public SalonSummary unblockSalon(@PathVariable Long id) {
        return service.unblockSalon(id);
    }

    @GetMapping("/salons/{id}/users")
    public List<PlatformUser> users(@PathVariable Long id) {
        return service.listUsers(id);
    }

    @PostMapping("/users/{id}/block")
    public PlatformUser blockUser(@PathVariable Long id, @Valid @RequestBody BlockRequest req) {
        return service.blockUser(id, req.reason());
    }

    @PostMapping("/users/{id}/unblock")
    public PlatformUser unblockUser(@PathVariable Long id) {
        return service.unblockUser(id);
    }

    /** Sem {@code app}, lista as versões dos dois apps. */
    @GetMapping("/releases")
    public List<ReleaseResponse> releases(@RequestParam(required = false) String app) {
        return releases.list(app == null || app.isBlank() ? null : MobileApp.parse(app));
    }

    @PutMapping("/releases/{id}/force-update")
    public ReleaseResponse forceUpdate(@PathVariable Long id, @RequestBody ForceUpdateRequest req) {
        return releases.setForceUpdate(id, req.forceUpdate());
    }

    /** Upload manual de APK pelo painel (mesmas regras do deploy pelo CI). */
    @PostMapping(value = "/releases", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ReleaseResponse upload(@RequestPart("file") MultipartFile file,
                                  @RequestParam String app,
                                  @RequestParam String versionName,
                                  @RequestParam int versionCode,
                                  @RequestParam(required = false) String releaseNotes,
                                  @RequestParam(defaultValue = "false") boolean forceUpdate) {
        return releases.publish(MobileApp.parse(app), file, versionName, versionCode, releaseNotes, forceUpdate);
    }
}
