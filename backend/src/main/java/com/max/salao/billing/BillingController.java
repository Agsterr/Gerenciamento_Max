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

    /** Tela de pagamento do site (cartão): a pessoa volta para o painel depois de pagar. */
    @PostMapping("/api/billing/web/checkout")
    public UrlResponse checkout(@AuthenticationPrincipal Jwt jwt) {
        return new UrlResponse(billing.webCheckout(Long.valueOf(jwt.getSubject())));
    }

    /** Portal para trocar o cartão, ver faturas ou cancelar a assinatura do site. */
    @PostMapping("/api/billing/web/portal")
    public UrlResponse portal() {
        return new UrlResponse(billing.webPortal());
    }
}
