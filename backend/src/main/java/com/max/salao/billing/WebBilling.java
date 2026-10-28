package com.max.salao.billing;

import com.max.salao.salon.Salon;

/** Cobrança pelo site: abre a tela de pagamento e o portal onde a pessoa troca o cartão ou cancela. */
public interface WebBilling {

    /** Endereço da tela de pagamento (Checkout) da mensalidade para este salão. */
    String checkoutUrl(Salon salon, String ownerEmail);

    /** Endereço do portal de assinatura (trocar cartão, ver faturas, cancelar). */
    String portalUrl(String customerId);
}
