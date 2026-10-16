package com.max.salao.pricing;

import java.math.BigDecimal;

import com.max.salao.pricing.PricingService.Result;
import com.max.salao.pricing.PricingService.Settings;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Ajuda na precificação dos serviços (somente dono). */
@RestController
@RequestMapping("/api/pricing")
public class PricingController {

    public record SettingsRequest(
            @NotNull @DecimalMin("0") @DecimalMax("50") BigDecimal cardFeePercent,
            @NotNull @DecimalMin("0") @DecimalMax("80") BigDecimal targetMarginPercent,
            @NotNull @DecimalMin("5") @DecimalMax("100") BigDecimal occupancyPercent,
            @DecimalMin("0") BigDecimal fixedMonthlyCost) {
    }

    private final PricingService service;

    public PricingController(PricingService service) {
        this.service = service;
    }

    @GetMapping
    public Result calculate() {
        return service.calculate();
    }

    @PutMapping("/settings")
    public Settings updateSettings(@Valid @RequestBody SettingsRequest req) {
        return service.updateSettings(new Settings(req.cardFeePercent(), req.targetMarginPercent(), req.occupancyPercent(),
                req.fixedMonthlyCost()));
    }
}
