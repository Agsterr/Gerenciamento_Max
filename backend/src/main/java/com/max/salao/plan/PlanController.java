package com.max.salao.plan;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PlanController {

    /** Condições do teste grátis, para a página de cadastro. */
    public record TrialTerms(int trialDays, int maxProfessionals, int maxServices, int maxCustomers,
                             String contactWhatsapp, String contactEmail) {
    }

    private final PlanService plans;
    private final PlatformSettings settings;

    public PlanController(PlanService plans, PlatformSettings settings) {
        this.plans = plans;
        this.settings = settings;
    }

    /** Situação do plano do salão logado (aviso de teste/vencido no painel e no app). */
    @GetMapping("/api/salon/plan")
    public PlanService.PlanInfo plan() {
        return plans.info();
    }

    @GetMapping("/api/public/plan")
    public TrialTerms terms() {
        PlatformSettings.Values v = settings.get();
        return new TrialTerms(v.trialDays(), v.maxProfessionals(), v.maxServices(), v.maxCustomers(),
                v.contactWhatsapp(), v.contactEmail());
    }
}
