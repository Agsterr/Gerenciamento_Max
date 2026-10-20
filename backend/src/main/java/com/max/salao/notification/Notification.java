package com.max.salao.notification;

import java.time.LocalDateTime;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import lombok.Getter;
import lombok.Setter;

/** Aviso para a equipe do salão. */
@Getter
@Setter
@Entity
public class Notification extends TenantEntity {

    public enum Type { BOOKED, CANCELED, RESCHEDULED, CONFIRMED, REMINDERS, STAFF_REMINDER }

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Type type;

    private Long appointmentId;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String message;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    private LocalDateTime readAt;

    /** Aviso só para este usuário (lembrete do profissional); nulo = toda a equipe. */
    private Long userId;

    /** Evita que o job repita o mesmo aviso. */
    private String dedupKey;
}
