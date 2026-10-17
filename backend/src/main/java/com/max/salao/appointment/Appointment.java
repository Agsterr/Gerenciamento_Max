package com.max.salao.appointment;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.customer.Customer;
import com.max.salao.professional.Professional;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Appointment extends TenantEntity {

    public enum Source { ADMIN, ONLINE }

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Professional professional;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "service_id")
    private ServiceItem service;

    @Column(nullable = false)
    private LocalDateTime startAt;

    @Column(nullable = false)
    private LocalDateTime endAt;

    @Setter(AccessLevel.NONE)
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AppointmentStatus status = AppointmentStatus.SCHEDULED;

    /** Valor cobrado (copiado do serviço na criação, ajustável no fechamento). */
    @Column(nullable = false)
    private BigDecimal price;

    @Column(nullable = false)
    private BigDecimal serviceCost = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal commissionAmount = BigDecimal.ZERO;

    @Setter(AccessLevel.NONE)
    private LocalDateTime startedAt;

    @Setter(AccessLevel.NONE)
    private LocalDateTime finishedAt;

    /** Observação do agendamento (feita pelo cliente ou pela recepção). */
    private String notes;

    /** Anotações do profissional (privadas do salão): tinta usada, tipo de corte, produtos... */
    private String serviceNotes;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false)
    private Source source;

    /** Código que o cliente usa para consultar/cancelar o agendamento online. */
    @Column(nullable = false, unique = true, updatable = false)
    private String publicToken = UUID.randomUUID().toString().replace("-", "");

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public void confirm() {
        requireOpen();
        status = AppointmentStatus.CONFIRMED;
    }

    public void start(LocalDateTime now) {
        requireOpen();
        status = AppointmentStatus.IN_PROGRESS;
        startedAt = now;
    }

    public void finish(LocalDateTime now, BigDecimal finalPrice) {
        if (!status.isOpen() && status != AppointmentStatus.IN_PROGRESS) {
            throw new BusinessException("Atendimento não pode ser finalizado no status " + status);
        }
        status = AppointmentStatus.DONE;
        finishedAt = now;
        if (finalPrice != null) {
            price = finalPrice;
        }
        serviceCost = service.getCost();
        commissionAmount = price.multiply(professional.getCommissionPercent())
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }

    public void cancel() {
        requireOpen();
        status = AppointmentStatus.CANCELED;
    }

    public void noShow() {
        requireOpen();
        status = AppointmentStatus.NO_SHOW;
    }

    /** Duração planejada (agenda). */
    public int plannedMinutes() {
        return (int) Duration.between(startAt, endAt).toMinutes();
    }

    /** Duração real (início→fim do atendimento), quando registrada. */
    public Long realMinutes() {
        return startedAt != null && finishedAt != null ? Duration.between(startedAt, finishedAt).toMinutes() : null;
    }

    private void requireOpen() {
        if (!status.isOpen()) {
            throw new BusinessException("Ação não permitida para agendamento com status " + status);
        }
    }
}
