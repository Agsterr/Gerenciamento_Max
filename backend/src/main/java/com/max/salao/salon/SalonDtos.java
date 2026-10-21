package com.max.salao.salon;

import java.time.LocalTime;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public final class SalonDtos {

    private SalonDtos() {
    }

    /** Horário de um dia (dias que não aparecem na lista = fechado). */
    public record DayHoursDto(
            @Min(1) @Max(7) int dayOfWeek,
            @NotNull LocalTime openTime,
            @NotNull LocalTime closeTime,
            LocalTime breakStart,
            LocalTime breakEnd) {

        static DayHoursDto from(DayHours h) {
            return new DayHoursDto(h.getDayOfWeek(), h.getOpenTime(), h.getCloseTime(), h.getBreakStart(), h.getBreakEnd());
        }

        DayHours toEntity() {
            return new DayHours(dayOfWeek, openTime, closeTime, breakStart, breakEnd);
        }
    }

    public record SalonRequest(
            @NotBlank String name,
            String phone,
            String address,
            @NotNull @Size(min = 1, max = 7, message = "abra pelo menos um dia") List<@Valid DayHoursDto> hours,
            @Min(5) @Max(120) int slotMinutes,
            /* nulo = mantém (apps antigos não mandam) */ ReminderMode reminderMode,
            /* nulo = mantém; um dos fusos de SalonZones */ String timezone) {
    }

    public record SalonResponse(Long id, String name, String slug, String phone, String address,
                                List<DayHoursDto> hours, String workDays, int slotMinutes,
                                ReminderMode reminderMode, List<Integer> reminderDays, String timezone) {

        public static SalonResponse from(Salon s) {
            return new SalonResponse(s.getId(), s.getName(), s.getSlug(), s.getPhone(), s.getAddress(),
                    SalonDtos.hours(s), s.workDays(), s.getSlotMinutes(),
                    s.getReminderMode(), s.getReminderMode().days(), s.getTimezone());
        }
    }

    public static List<DayHoursDto> hours(Salon s) {
        return s.getHours().stream().map(DayHoursDto::from).toList();
    }
}
