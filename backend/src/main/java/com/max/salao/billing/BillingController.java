package com.max.salao.billing;

import com.max.salao.plan.PlanService.PlanInfo;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/** Assinatura pela Google Play (só o dono do salão). */
@RestController
public class BillingController {

    public record UrlResponse(String url) {
    }

    public record CheckoutRequest(@Size(max = 30) String cpfCnpj) {
    }

    public record VerifyRequest(@NotBlank @Size(max = 100) String productId, @NotBlank @Size(max = 400) String purchaseToken) {
    }

    private final BillingService billing;

    public BillingController(BillingService billing) {
        this.billing = billing;
    }

    /** O app acabou de comprar (ou restaurou): a API confere com a Google e ativa o plano. */
    @PostMapping("/api/billing/play/verify")
    public PlanInfo verify(@Valid @RequestBody VerifyRequest req) {
        return billing.verify(req.productId(), req.purchaseToken());
    }

    /** Reconfere a assinatura que já está ligada ao salão. */
    @PostMapping("/api/billing/play/sync")
    public PlanInfo sync() {
        return billing.sync();
    }

    /** Página de pagamento do site (Pix, boleto ou cartão): a pessoa volta para o painel depois de pagar. */
    @PostMapping("/api/billing/web/checkout")
    public UrlResponse checkout(@AuthenticationPrincipal Jwt jwt, @RequestBody(required = false) CheckoutRequest req) {
        return new UrlResponse(billing.webCheckout(Long.valueOf(jwt.getSubject()), req == null ? null : req.cpfCnpj()));
    }

    /** Cancela a assinatura feita pelo site; o plano vale até o fim do período já pago. */
    @PostMapping("/api/billing/web/cancel")
    public PlanInfo cancel() {
        return billing.webCancel();
    }
}
