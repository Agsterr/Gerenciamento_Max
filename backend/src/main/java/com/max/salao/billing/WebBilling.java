package com.max.salao.billing;

import com.max.salao.salon.Salon;

/** Cobrança pelo site: cria a página de pagamento da mensalidade e cancela a assinatura. */
public interface WebBilling {

    /** Página de pagamento da mensalidade para este salão (a pessoa escolhe Pix, boleto ou cartão). */
    Link createLink(Salon salon);

    /** Link já criado (para reaproveitar a mesma página se a pessoa clicar de novo); vazio se não existe mais. */
    java.util.Optional<Link> findLink(String linkId);

    /** Cancela a assinatura (não gera mais cobranças; o que já foi pago continua valendo). */
    void cancelSubscription(String subscriptionId);

    /** @param id identificador do link no Asaas (liga o pagamento ao salão) @param url endereço para abrir */
    record Link(String id, String url) {
    }
}
