package com.max.salao.billing;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Todo dia reconfere com a Google as assinaturas que vencem em breve (renovou? cancelou? falhou o pagamento?). */
@Component
class PlaySubscriptionJob {

    private final BillingService billing;

    PlaySubscriptionJob(BillingService billing) {
        this.billing = billing;
    }

    @Scheduled(cron = "${app.billing.cron:0 0 5 * * *}", zone = "${app.timezone}")
    void run() {
        billing.syncDue();
    }
}
