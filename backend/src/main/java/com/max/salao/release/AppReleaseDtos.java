package com.max.salao.release;

import java.time.LocalDateTime;

public final class AppReleaseDtos {

    private AppReleaseDtos() {
    }

    /** Resposta de {@code GET /api/app/version}: contrato usado pelos apps e pelo workflow de release. */
    public record VersionResponse(
            String versionName,
            int versionCode,
            String downloadUrl,
            String releaseNotes,
            boolean forceUpdate,
            String sha256) {
    }

    public record ReleaseResponse(
            Long id,
            String app,
            String versionName,
            int versionCode,
            String fileName,
            long fileSizeBytes,
            String sha256,
            String releaseNotes,
            boolean forceUpdate,
            String downloadUrl,
            LocalDateTime createdAt) {
    }

    public record ForceUpdateRequest(boolean forceUpdate) {
    }
}
