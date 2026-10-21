package com.max.salao.billing;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param playPackage        pacote do app de gestão na Play
 * @param serviceAccountJson JSON da conta de serviço (texto puro ou base64); vazio = compra desligada
 */
@ConfigurationProperties("app.billing")
public record BillingProperties(String playPackage, String serviceAccountJson) {

    public BillingProperties {
        playPackage = playPackage == null ? "" : playPackage.trim();
        serviceAccountJson = decode(serviceAccountJson == null ? "" : serviceAccountJson.trim());
    }

    private static String decode(String value) {
        if (value.isEmpty() || value.startsWith("{")) {
            return value;
        }
        return new String(Base64.getMimeDecoder().decode(value), StandardCharsets.UTF_8);
    }

    public boolean configured() {
        return !playPackage.isEmpty() && !serviceAccountJson.isEmpty();
    }
}
