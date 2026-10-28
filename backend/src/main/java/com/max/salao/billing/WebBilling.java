package com.max.salao.billing;

import java.util.Optional;

import com.max.salao.salon.Salon;

/** Cobrança pelo site: cria a assinatura mensal, acha a cobrança em aberto e cancela. */
public interface WebBilling {

    /**
     * Cria (ou reaproveita) o cliente e a assinatura mensal no Asaas e devolve a página da primeira cobrança, onde a
     * pessoa escolhe Pix, boleto ou cartão.
     *
     * @param cpfCnpj documento do titular (obrigatório no Asaas; pode ser nulo se o salão já é cliente lá)
     */
    Subscribed subscribe(Salon salon, String ownerName, String ownerEmail, String cpfCnpj);

    /** Página da cobrança ainda em aberto (pendente/vencida) da assinatura, para reaproveitar; vazio se não há. */
    Optional<String> openPaymentUrl(String subscriptionId);

    /** Cancela a assinatura (não gera mais cobranças; o que já foi pago continua valendo). */
    void cancelSubscription(String subscriptionId);

    record Subscribed(String customerId, String subscriptionId, String url) {
    }
}
