package com.max.salao.platform;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.max.salao.auth.Role;
import com.max.salao.plan.Plan;
import com.max.salao.plan.PlanStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class PlatformDtos {

    private PlatformDtos() {
    }

    public record SalonSummary(
            Long id,
            String name,
            String slug,
            String phone,
            String address,
            LocalDateTime createdAt,
            long userCount,
            boolean blocked,
            String blockedReason,
            LocalDateTime blockedAt,
            Plan plan,
            PlanStatus planStatus,
            LocalDateTime trialEndsAt,
            LocalDate paidUntil) {
    }

    /** PAID com {@code paidUntil} nulo = sem vencimento; TRIAL usa {@code trialEndsAt}. */
    public record PlanRequest(@NotNull Plan plan, LocalDate paidUntil, LocalDateTime trialEndsAt) {
    }

    public record SettingsRequest(
            @Min(1) @Max(365) int trialDays,
            @Min(1) @Max(1000) int maxProfessionals,
            @Min(1) @Max(1000) int maxServices,
            @Min(1) @Max(100000) int maxCustomers,
            @Size(max = 30) String contactWhatsapp,
            @Size(max = 120) String contactEmail,
            /* nulos = mantém (painel antigo não manda) */ @Min(0) @Max(10000) Integer maxPhotos,
            @Min(0) @Max(10000) Integer maxPhotosPaid) {
    }

    public record PlatformUser(
            Long id,
            String name,
            String email,
            Role role,
            boolean active,
            boolean blocked,
            String blockedReason,
            LocalDateTime blockedAt) {
    }

    public record BlockRequest(@NotBlank @Size(max = 300) String reason) {
    }
}
