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

    /** Refação: o cliente voltou para refazer e não pagou. O custo continua contando. */
    @Column(nullable = false)
    private boolean rework;

    /** Promoção aplicada no preço (se houver) e quanto ela descontou. */
    @ManyToOne(fetch = FetchType.LAZY)
    private com.max.salao.promotion.Promotion promotion;

    @Column(nullable = false)
    private BigDecimal discountAmount = BigDecimal.ZERO;

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

    /** Cancelado pelo cliente com a vaga mantida pelo salão (ainda conta como ocupada na agenda). */
    @Setter(AccessLevel.NONE)
    private boolean slotHeld;

    /** Quando o salão mandou o lembrete de confirmação (WhatsApp). */
    private LocalDateTime reminderSentAt;

    /** Quando o próprio cliente confirmou a presença (link do lembrete ou app). */
    @Setter(AccessLevel.NONE)
    private LocalDateTime customerConfirmedAt;

    /** Quando o salão aceitou o agendamento (nulo = ainda aguardando a confirmação do salão). */
    @Setter(AccessLevel.NONE)
    private LocalDateTime salonConfirmedAt;

    /** Agendamento do cliente que o salão ainda não aceitou. */
    public boolean isPendingAcceptance() {
        return status.isOpen() && salonConfirmedAt == null;
    }

    /** O salão aceita o horário (agendamentos do próprio salão já nascem aceitos). */
    public void accept(LocalDateTime now) {
        requireOpen();
        if (salonConfirmedAt == null) {
            salonConfirmedAt = now;
        }
    }

    /** Horário mudou por iniciativa do cliente: o salão precisa aceitar de novo. */
    public void requireAcceptanceAgain() {
        salonConfirmedAt = null;
    }

    public void confirm() {
        requireOpen();
        status = AppointmentStatus.CONFIRMED;
    }

    /** Cliente confirmou pelo lembrete. Repetir não muda nada (o link pode ser aberto várias vezes). */
    public void confirmByCustomer(LocalDateTime now) {
        requireOpen();
        status = AppointmentStatus.CONFIRMED;
        if (customerConfirmedAt == null) {
            customerConfirmedAt = now;
        }
    }

    public void start(LocalDateTime now) {
        requireOpen();
        status = AppointmentStatus.IN_PROGRESS;
        startedAt = now;
    }

    public void finish(LocalDateTime now, BigDecimal finalPrice) {
        finish(now, finalPrice, false);
    }

    /** {@code rework}: refação sem cobrança (valor e comissão zerados; material e produtos contam como custo). */
    public void finish(LocalDateTime now, BigDecimal finalPrice, boolean rework) {
        if (!status.isOpen() && status != AppointmentStatus.IN_PROGRESS) {
            throw new BusinessException("Atendimento não pode ser finalizado no status " + status);
        }
        status = AppointmentStatus.DONE;
        finishedAt = now;
        this.rework = rework;
        if (rework) {
            price = BigDecimal.ZERO;
        } else if (finalPrice != null) {
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

    /** Cancelado pelo cliente, mas o salão escolheu não liberar a vaga: o horário segue bloqueado na agenda. */
    public void cancelKeepingSlot() {
        cancel();
        slotHeld = true;
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
