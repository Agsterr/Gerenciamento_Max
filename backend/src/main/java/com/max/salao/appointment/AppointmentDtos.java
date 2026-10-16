package com.max.salao.appointment;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public final class AppointmentDtos {

    private AppointmentDtos() {
    }

    public record AppointmentRequest(
            @NotNull Long customerId,
            /* nulo = qualquer profissional livre */ Long professionalId,
            @NotNull Long serviceId,
            @NotNull LocalDateTime startAt,
            String notes,
            /* duração manual em minutos; nulo = duração do serviço */ @Min(5) @Max(720) Integer durationMinutes,
            /* encaixe: ignora conflito de agenda e horário de funcionamento */ boolean force) {
    }

    public record ProductQuantity(@NotNull Long productId, @NotNull @DecimalMin("0.001") BigDecimal quantity) {
    }

    public record FinishRequest(
            @DecimalMin("0") BigDecimal price,
            List<@Valid ProductQuantity> usedProducts,
            List<@Valid ProductQuantity> soldProducts) {
    }

    public record Ref(Long id, String name) {
    }

    public record AppointmentResponse(
            Long id,
            LocalDateTime startAt,
            LocalDateTime endAt,
            AppointmentStatus status,
            Ref customer,
            String customerPhone,
            Ref professional,
            Ref service,
            int estimatedMinutes,
            Long realMinutes,
            BigDecimal price,
            BigDecimal commissionAmount,
            LocalDateTime startedAt,
            LocalDateTime finishedAt,
            String notes,
            Appointment.Source source) {

        public static AppointmentResponse from(Appointment a) {
            return new AppointmentResponse(a.getId(), a.getStartAt(), a.getEndAt(), a.getStatus(),
                    new Ref(a.getCustomer().getId(), a.getCustomer().getName()), a.getCustomer().getPhone(),
                    new Ref(a.getProfessional().getId(), a.getProfessional().getName()),
                    new Ref(a.getService().getId(), a.getService().getName()),
                    a.plannedMinutes(), a.realMinutes(), a.getPrice(), a.getCommissionAmount(),
                    a.getStartedAt(), a.getFinishedAt(), a.getNotes(), a.getSource());
        }
    }
}
