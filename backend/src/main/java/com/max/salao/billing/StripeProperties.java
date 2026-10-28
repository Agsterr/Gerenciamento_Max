package com.max.salao.billing;

/**
 * Pagamento pelo site (Stripe Billing).
 *
 * @param secretKey     chave secreta da API ({@code STRIPE_SECRET_KEY}, sk_live_... ou sk_test_...)
 * @param priceId       preço recorrente da mensalidade ({@code STRIPE_PRICE_ID}, price_...)
 * @param webhookSecret segredo do endpoint de webhook ({@code STRIPE_WEBHOOK_SECRET}, whsec_...)
 * @param siteUrl       endereço público do site (para onde o Stripe devolve a pessoa)
 */
@org.springframework.boot.context.properties.ConfigurationProperties("app.stripe")
public record StripeProperties(String secretKey, String priceId, String webhookSecret, String siteUrl) {

    public StripeProperties {
        secretKey = secretKey == null ? "" : secretKey.trim();
        priceId = priceId == null ? "" : priceId.trim();
        webhookSecret = webhookSecret == null ? "" : webhookSecret.trim();
        siteUrl = siteUrl == null ? "" : siteUrl.trim().replaceAll("/+$", "");
    }

    public boolean configured() {
        return !secretKey.isEmpty() && !priceId.isEmpty() && !webhookSecret.isEmpty();
    }
}
