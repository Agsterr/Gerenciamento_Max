package com.max.salao.appointment;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.professional.Professional;
import com.max.salao.salon.Salon;
import com.max.salao.shared.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Calcula horários livres a partir do expediente do salão e da agenda de cada profissional. */
@Service
public class AvailabilityService {

    public record Slot(LocalTime time, List<Long> professionalIds) {
    }

    private final AppointmentRepository appointments;
    private final Clock clock;

    public AvailabilityService(AppointmentRepository appointments, Clock clock) {
        this.appointments = appointments;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<Slot> slots(Salon salon, ServiceItem service, List<Professional> professionals, LocalDate date) {
        if (!salon.workDaySet().contains(date.getDayOfWeek()) || professionals.isEmpty()) {
            return List.of();
        }
        LocalDateTime dayStart = date.atTime(salon.getOpenTime());
        LocalDateTime dayEnd = date.atTime(salon.getCloseTime());
        List<Appointment> busy = appointments.findBusy(dayStart, dayEnd, AppointmentStatus.FREEING);
        LocalDateTime now = LocalDateTime.now(clock);

        List<Slot> slots = new ArrayList<>();
        for (LocalDateTime t = dayStart;
             !t.plusMinutes(service.getDurationMinutes()).isAfter(dayEnd);
             t = t.plusMinutes(salon.getSlotMinutes())) {
            if (t.isBefore(now)) {
                continue;
            }
            LocalDateTime start = t;
            LocalDateTime end = t.plusMinutes(service.getDurationMinutes());
            List<Long> free = new ArrayList<>();
            for (Professional p : professionals) {
                if (busy.stream().noneMatch(a -> overlaps(a, p.getId(), start, end))) {
                    free.add(p.getId());
                }
            }
            if (!free.isEmpty()) {
                slots.add(new Slot(start.toLocalTime(), free));
            }
        }
        return slots;
    }

    /** Valida expediente e conflito. Chamar com o profissional já travado (FOR UPDATE). */
    public void assertBookable(Salon salon, Long professionalId, LocalDateTime start, LocalDateTime end,
                               Long ignoreAppointmentId) {
        if (!salon.workDaySet().contains(start.getDayOfWeek())) {
            throw new BusinessException("O salão não funciona nesse dia");
        }
        if (start.toLocalTime().isBefore(salon.getOpenTime()) || end.toLocalTime().isAfter(salon.getCloseTime())
                || !end.toLocalDate().equals(start.toLocalDate())) {
            throw new BusinessException("Fora do horário de funcionamento");
        }
        boolean conflict = appointments.findBusy(start, end, AppointmentStatus.FREEING).stream()
                .filter(a -> !a.getId().equals(ignoreAppointmentId))
                .anyMatch(a -> overlaps(a, professionalId, start, end));
        if (conflict) {
            throw new BusinessException("Horário indisponível para este profissional");
        }
    }

    private static boolean overlaps(Appointment a, Long professionalId, LocalDateTime start, LocalDateTime end) {
        return a.getProfessional().getId().equals(professionalId)
                && a.getStartAt().isBefore(end) && a.getEndAt().isAfter(start);
    }
}
