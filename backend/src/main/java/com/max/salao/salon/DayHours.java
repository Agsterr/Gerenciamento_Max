package com.max.salao.salon;

import java.time.Duration;
import java.time.LocalTime;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Horário de um dia da semana, com pausa opcional (ex.: almoço). */
@Getter
@Setter
@Embeddable
@NoArgsConstructor
@AllArgsConstructor
public class DayHours {

    /** ISO: 1 = segunda ... 7 = domingo. */
    @Column(name = "day_of_week", nullable = false)
    private int dayOfWeek;

    @Column(nullable = false)
    private LocalTime openTime;

    @Column(nullable = false)
    private LocalTime closeTime;

    private LocalTime breakStart;
    private LocalTime breakEnd;

    public boolean hasBreak() {
        return breakStart != null && breakEnd != null;
    }

    /** Intervalo [start, end) cabe no expediente e não encosta na pausa. */
    public boolean fits(LocalTime start, LocalTime end) {
        if (start.isBefore(openTime) || end.isAfter(closeTime) || !end.isAfter(start)) {
            return false;
        }
        return !hasBreak() || !(start.isBefore(breakEnd) && end.isAfter(breakStart));
    }

    /** Minutos de trabalho no dia (sem a pausa). */
    public long workMinutes() {
        long total = Duration.between(openTime, closeTime).toMinutes();
        return hasBreak() ? total - Duration.between(breakStart, breakEnd).toMinutes() : total;
    }
}
