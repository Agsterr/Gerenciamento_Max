package com.max.salao.shop;

/**
 * Assinatura da loja do representante.
 *
 * @param priceCents mensalidade em centavos (padrão R$ 49,90), cobrada pelo Asaas
 * @param trialDays  dias de teste grátis a partir do primeiro uso da loja
 */
@org.springframework.boot.context.properties.ConfigurationProperties("app.shop")
public record ShopProperties(Integer priceCents, Integer trialDays) {

    public ShopProperties {
        priceCents = priceCents == null ? 4990 : priceCents;
        trialDays = trialDays == null ? 7 : trialDays;
    }
}
