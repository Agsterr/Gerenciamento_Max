package com.max.salao.salon;

import java.time.LocalTime;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public final class SalonDtos {

    private SalonDtos() {
    }

    public record SalonRequest(
            @NotBlank String name,
            String phone,
            String address,
            @NotNull LocalTime openTime,
            @NotNull LocalTime closeTime,
            @NotBlank @Pattern(regexp = "[1-7](,[1-7])*", message = "ex.: 2,3,4,5,6") String workDays,
            @Min(5) @Max(120) int slotMinutes) {
    }

    public record SalonResponse(Long id, String name, String slug, String phone, String address,
                                LocalTime openTime, LocalTime closeTime, String workDays, int slotMinutes) {

        public static SalonResponse from(Salon s) {
            return new SalonResponse(s.getId(), s.getName(), s.getSlug(), s.getPhone(), s.getAddress(),
                    s.getOpenTime(), s.getCloseTime(), s.getWorkDays(), s.getSlotMinutes());
        }
    }
}
