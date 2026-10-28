package com.max.salao.billing;

/**
 * Cobrança pelo site (Asaas: Pix, boleto e cartão).
 *
 * @param apiKey       chave de API ({@code ASAAS_API_KEY}); fica só no servidor
 * @param webhookToken token que o Asaas manda no cabeçalho {@code asaas-access-token} ({@code ASAAS_WEBHOOK_TOKEN})
 * @param baseUrl      {@code https://api.asaas.com/v3} (produção) ou {@code https://api-sandbox.asaas.com/v3} (testes)
 * @param priceCents   mensalidade pelo site, em centavos (padrão R$ 49,90)
 * @param siteUrl      endereço público do site (para onde o Asaas devolve a pessoa depois de pagar)
 */
@org.springframework.boot.context.properties.ConfigurationProperties("app.asaas")
public record AsaasProperties(String apiKey, String webhookToken, String baseUrl, Integer priceCents, String siteUrl) {

    public AsaasProperties {
        apiKey = apiKey == null ? "" : apiKey.trim();
        webhookToken = webhookToken == null ? "" : webhookToken.trim();
        baseUrl = baseUrl == null || baseUrl.isBlank() ? "https://api.asaas.com/v3" : baseUrl.trim().replaceAll("/+$", "");
        priceCents = priceCents == null ? 4990 : priceCents;
        siteUrl = siteUrl == null ? "" : siteUrl.trim().replaceAll("/+$", "");
    }

    public boolean configured() {
        return !apiKey.isEmpty() && !webhookToken.isEmpty();
    }
}
