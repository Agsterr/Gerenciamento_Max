package com.max.salao.billing;

/** Conversa com a API da Google Play (Android Publisher) para conferir e confirmar assinaturas. */
public interface PlayBilling {

    /** @throws com.max.salao.shared.BusinessException se a compra não existe ou a cobrança não está configurada */
    PlaySubscription lookup(String purchaseToken);

    /** Pedidos de assinatura estornados/cancelados com reembolso pela Google desde a data (idempotente). */
    default java.util.List<String> voidedOrderIds(java.time.Instant since) {
        return java.util.List.of();
    }

    /** Confirma (acknowledge) a compra; sem isso a Google devolve o dinheiro após 3 dias. */
    void acknowledge(String productId, String purchaseToken);
}
