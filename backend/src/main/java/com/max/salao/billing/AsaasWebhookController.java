package com.max.salao.billing;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Webhook do Asaas: público, protegido pelo token do cabeçalho {@code asaas-access-token}. */
@RestController
public class AsaasWebhookController {

    private final AsaasWebhookService service;

    public AsaasWebhookController(AsaasWebhookService service) {
        this.service = service;
    }

    @PostMapping("/api/asaas/webhook")
    @ResponseStatus(HttpStatus.OK)
    public void receive(@RequestBody String payload, @RequestHeader(value = "asaas-access-token", required = false) String token) {
        service.verify(token);
        service.handle(payload);
    }
}
