package com.max.salao.salon;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

/** O tenant. Cada salão tem seus próprios dados e uma página pública em /s/{slug}. */
@Getter
@Setter
@Entity
public class Salon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true, updatable = false)
    private String slug;

    private String phone;
    private String address;

    @Column(nullable = false)
    private LocalTime openTime = LocalTime.of(9, 0);

    @Column(nullable = false)
    private LocalTime closeTime = LocalTime.of(19, 0);

    /** Dias de funcionamento, ISO (1 = segunda ... 7 = domingo), separados por vírgula. */
    @Column(nullable = false)
    private String workDays = "2,3,4,5,6";

    @Column(nullable = false)
    private int slotMinutes = 30;

    public Set<DayOfWeek> workDaySet() {
        return Arrays.stream(workDays.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(s -> DayOfWeek.of(Integer.parseInt(s)))
                .collect(Collectors.toSet());
    }
}
