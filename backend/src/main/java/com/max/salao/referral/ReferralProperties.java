package com.max.salao.referral;

/**
 * @param commissionCents comissão fixa por mensalidade paga de um salão indicado (padrão R$ 15,00)
 * @param holdDays        dias até a comissão ficar disponível para repasse (prazo de arrependimento/estorno)
 * @param playPriceCents  valor da mensalidade pela Play (só informativo no registro de pagamentos)
 * @param siteUrl         endereço público do site, base do link do representante
 */
@org.springframework.boot.context.properties.ConfigurationProperties("app.referral")
public record ReferralProperties(Integer commissionCents, Integer holdDays, Integer playPriceCents, String siteUrl) {

    public ReferralProperties {
        commissionCents = commissionCents == null ? 1500 : commissionCents;
        holdDays = holdDays == null ? 7 : holdDays;
        playPriceCents = playPriceCents == null ? 4990 : playPriceCents;
        siteUrl = siteUrl == null ? "" : siteUrl.trim().replaceAll("/+$", "");
    }
}
