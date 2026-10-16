package com.max.salao.appointment;

import java.util.EnumSet;
import java.util.Set;

public enum AppointmentStatus {
    SCHEDULED, CONFIRMED, IN_PROGRESS, DONE, CANCELED, NO_SHOW;

    /** Status que não ocupam mais a agenda. */
    public static final Set<AppointmentStatus> FREEING = EnumSet.of(CANCELED, NO_SHOW);

    public boolean isOpen() {
        return this == SCHEDULED || this == CONFIRMED;
    }
}
