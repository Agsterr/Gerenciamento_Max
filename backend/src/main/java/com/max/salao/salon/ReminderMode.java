package com.max.salao.salon;

import java.util.List;

/** Com quantos dias de antecedência o cliente é lembrado de confirmar o horário. */
public enum ReminderMode {
    OFF(List.of()), ONE_DAY(List.of(1)), TWO_DAYS(List.of(2)), BOTH(List.of(1, 2));

    private final List<Integer> days;

    ReminderMode(List<Integer> days) {
        this.days = days;
    }

    /** Dias antes do agendamento em que o lembrete sai (vazio = desligado). */
    public List<Integer> days() {
        return days;
    }
}
