package com.max.salao.portfolio;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Onde ficam as fotos do portfólio. Com as cinco variáveis do R2 preenchidas, vão para o
 * Cloudflare R2 (como os vídeos do foco-academia); faltando qualquer uma, vão para o disco
 * ({@code APP_MEDIA_PATH}, volume em produção) e são servidas em /api/public/media/**.
 *
 * @param storagePath     pasta local ({@code APP_MEDIA_PATH})
 * @param maxUploadMb     tamanho máximo do arquivo enviado, antes de comprimir
 * @param r2Bucket        {@code R2_BUCKET}
 * @param r2Endpoint      {@code R2_ENDPOINT} (https://ACCOUNT_ID.r2.cloudflarestorage.com)
 * @param r2AccessKeyId   {@code R2_ACCESS_KEY_ID}
 * @param r2SecretAccessKey {@code R2_SECRET_ACCESS_KEY}
 * @param r2PublicBaseUrl {@code R2_PUBLIC_BASE_URL} (domínio público do bucket, ex.: https://pub-xxx.r2.dev)
 */
@ConfigurationProperties("app.media")
public record MediaProperties(String storagePath, int maxUploadMb, String r2Bucket, String r2Endpoint,
                              String r2AccessKeyId, String r2SecretAccessKey, String r2PublicBaseUrl) {

    public MediaProperties {
        if (storagePath == null || storagePath.isBlank()) {
            storagePath = "/app/media";
        }
        if (maxUploadMb < 1) {
            maxUploadMb = 15;
        }
        r2Bucket = trim(r2Bucket);
        r2Endpoint = trim(r2Endpoint).replaceAll("/+$", "");
        r2AccessKeyId = trim(r2AccessKeyId);
        r2SecretAccessKey = trim(r2SecretAccessKey);
        r2PublicBaseUrl = trim(r2PublicBaseUrl).replaceAll("/+$", "");
    }

    public boolean r2Enabled() {
        return !r2Bucket.isEmpty() && !r2Endpoint.isEmpty() && !r2AccessKeyId.isEmpty()
                && !r2SecretAccessKey.isEmpty() && !r2PublicBaseUrl.isEmpty();
    }

    private static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
