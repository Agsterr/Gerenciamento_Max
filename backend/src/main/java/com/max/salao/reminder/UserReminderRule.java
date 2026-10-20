package com.max.salao.reminder;

import java.time.LocalDateTime;
import java.time.LocalTime;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

/**
 * Lembrete de atendimento escolhido pelo próprio usuário do salão: "N dias antes, às HH:mm"
 * ({@code daysBefore} + {@code atTime}) ou "X minutos antes" ({@code minutesBefore}).
 */
@Getter
@Setter
@Entity
public class UserReminderRule extends TenantEntity {

    @Column(nullable = false)
    private Long userId;

    private Integer daysBefore;

    private LocalTime atTime;

    private Integer minutesBefore;

    /** Quando avisar sobre um atendimento que começa em {@code startAt}. */
    public LocalDateTime remindAt(LocalDateTime startAt) {
        return minutesBefore != null ? startAt.minusMinutes(minutesBefore)
                : startAt.toLocalDate().minusDays(daysBefore).atTime(atTime);
    }
}
