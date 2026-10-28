package com.max.salao.billing;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Webhook do Stripe: público, protegido pela assinatura do cabeçalho (corpo cru, sem reprocessar o JSON). */
@RestController
public class StripeWebhookController {

    private final StripeWebhookService service;

    public StripeWebhookController(StripeWebhookService service) {
        this.service = service;
    }

    @PostMapping("/api/stripe/webhook")
    @ResponseStatus(HttpStatus.OK)
    public void receive(@RequestBody String payload, @RequestHeader(value = "Stripe-Signature", required = false) String signature) {
        service.verify(payload, signature);
        service.handle(payload);
    }
}
