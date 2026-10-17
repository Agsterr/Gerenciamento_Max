package com.max.salao.release;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param storagePath   pasta dos APKs ({@code APP_RELEASES_PATH})
 * @param maxRetained   quantas versões manter por app ({@code APP_RELEASES_MAX_COUNT})
 * @param deployToken   segredo do header {@code X-Deploy-Token} ({@code APP_RELEASE_DEPLOY_TOKEN}); vazio desliga o deploy
 * @param publicBaseUrl URL pública usada nos links de download ({@code APP_PUBLIC_URL})
 */
@ConfigurationProperties("app.releases")
public record AppReleaseProperties(String storagePath, int maxRetained, String deployToken, String publicBaseUrl) {

    public AppReleaseProperties {
        if (storagePath == null || storagePath.isBlank()) {
            storagePath = "/app/releases";
        }
        if (maxRetained < 1) {
            maxRetained = 2;
        }
        if (deployToken == null) {
            deployToken = "";
        }
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            publicBaseUrl = "https://salaomax.focodev.com.br";
        }
        publicBaseUrl = publicBaseUrl.replaceAll("/+$", "");
    }
}
