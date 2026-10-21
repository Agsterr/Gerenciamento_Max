package com.max.salao.billing;

import java.time.Instant;

/**
 * Situação de uma assinatura na Google Play.
 *
 * @param state        SUBSCRIPTION_STATE_* da API
 * @param expiry       fim do período já pago (pode ser nulo se a compra ainda está pendente)
 * @param acknowledged a compra já foi confirmada (a Google estorna sozinha se ninguém confirmar em 3 dias)
 */
public record PlaySubscription(String state, String productId, Instant expiry, boolean acknowledged, String orderId) {

    /**
     * Dá direito ao plano pago: ativa, em prazo de carência (cobrança falhou mas ainda vale) ou cancelada
     * pelo usuário que ainda tem tempo pago. Em espera, pausada, pendente ou expirada, não.
     */
    public boolean entitled(Instant now) {
        return switch (state) {
            case "SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" -> true;
            case "SUBSCRIPTION_STATE_CANCELED" -> expiry != null && expiry.isAfter(now);
            default -> false;
        };
    }
}
