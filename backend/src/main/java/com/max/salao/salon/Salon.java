package com.max.salao.salon;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import com.max.salao.plan.Plan;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OrderBy;
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

    /** Horário de cada dia em que o salão abre (dias ausentes = fechado). */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "opening_hours", joinColumns = @JoinColumn(name = "salon_id"))
    @OrderBy("dayOfWeek")
    private List<DayHours> hours = defaultHours();

    @Column(nullable = false)
    private int slotMinutes = 30;

    /** Fuso do salão (IANA): todos os horários dele são a hora local nesse fuso. */
    @Column(nullable = false)
    private String timezone = "America/Sao_Paulo";

    /** Lembrete para o cliente confirmar o horário (app do cliente e lista de lembretes do salão). */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReminderMode reminderMode = ReminderMode.ONE_DAY;

    // ---- Precificação ----

    /** Taxa média de cartão/maquininha + impostos sobre o faturamento (%). */
    @Column(nullable = false)
    private BigDecimal cardFeePercent = BigDecimal.valueOf(4);

    /** Lucro desejado sobre o preço (%). */
    @Column(nullable = false)
    private BigDecimal targetMarginPercent = BigDecimal.valueOf(20);

    /** Quanto da agenda costuma estar ocupada (%). Divide o custo fixo pelas horas realmente vendidas. */
    @Column(nullable = false)
    private BigDecimal occupancyPercent = BigDecimal.valueOf(70);

    /** Custo fixo mensal informado; nulo = média das despesas dos últimos 3 meses. */
    private BigDecimal fixedMonthlyCost;

    // ---- Bloqueio pela plataforma ----

    private boolean blocked;
    private String blockedReason;
    private LocalDateTime blockedAt;

    // ---- Plano (teste grátis / pago), ver PlanService ----

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Plan plan = Plan.TRIAL;

    @Column(nullable = false)
    private LocalDateTime trialEndsAt = LocalDateTime.now().plusDays(14);

    /** Plano pago válido até esta data (inclusive); nulo = sem vencimento. */
    private LocalDate paidUntil;

    @Column(insertable = false, updatable = false)
    private LocalDateTime createdAt;

    /** Padrão de um salão novo: terça a sábado, 9h às 19h. */
    public static List<DayHours> defaultHours() {
        List<DayHours> list = new ArrayList<>();
        for (int d = 2; d <= 6; d++) {
            list.add(new DayHours(d, LocalTime.of(9, 0), LocalTime.of(19, 0), null, null));
        }
        return list;
    }

    public Optional<DayHours> hoursFor(DayOfWeek day) {
        return hours.stream().filter(h -> h.getDayOfWeek() == day.getValue()).findFirst();
    }

    public Set<DayOfWeek> workDaySet() {
        return hours.stream().map(h -> DayOfWeek.of(h.getDayOfWeek())).collect(Collectors.toSet());
    }

    /** Dias de funcionamento no formato "2,3,4,5,6" (compatibilidade com os apps). */
    public String workDays() {
        return hours.stream().map(h -> String.valueOf(h.getDayOfWeek())).sorted().collect(Collectors.joining(","));
    }
}
