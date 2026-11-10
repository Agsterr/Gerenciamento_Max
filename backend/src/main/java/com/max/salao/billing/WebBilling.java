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

    /**
     * Assinatura mensal de outro tipo de cliente (ex.: representante pela loja): cria o cliente se {@code customerId} for
     * nulo e devolve a página da primeira cobrança.
     *
     * @param reference referência para achar de volta nos avisos (ex.: {@code rep:12})
     */
    Subscribed subscribeCustom(String customerId, String name, String email, String cpfCnpj, int priceCents, String description, String reference);

    /** Página da cobrança ainda em aberto (pendente/vencida) da assinatura, para reaproveitar; vazio se não há. */
    Optional<String> openPaymentUrl(String subscriptionId);

    /** Cancela a assinatura (não gera mais cobranças; o que já foi pago continua valendo). */
    void cancelSubscription(String subscriptionId);

    record Subscribed(String customerId, String subscriptionId, String url) {
    }
}
