package com.max.salao.pricing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.expense.Expense;
import com.max.salao.expense.ExpenseRepository;
import com.max.salao.professional.Professional;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.salon.DayHours;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Calculadora de preços por "markup divisor":
 * <pre>
 *   custo direto   = material + custo fixo por hora × duração
 *   preço mínimo   = custo direto / (1 − comissão% − taxas%)            (lucro zero)
 *   preço sugerido = custo direto / (1 − comissão% − taxas% − margem%)  (lucro desejado)
 * </pre>
 * O custo fixo por hora é o custo fixo do mês dividido pelas horas que o salão realmente vende
 * (horário × dias × profissionais × ocupação).
 */
@Service
public class PricingService {

    static final int HISTORY_DAYS = 90;
    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final double WEEKS_PER_MONTH = 52.0 / 12;

    public enum Health { LOSS, LOW, HEALTHY, NO_PRICE }

    public record Settings(BigDecimal cardFeePercent, BigDecimal targetMarginPercent, BigDecimal occupancyPercent,
                           BigDecimal fixedMonthlyCost) {
    }

    /** Base do cálculo, mostrada na tela para o dono entender de onde vêm os números. */
    public record Basis(
            BigDecimal monthlyFixedCost,
            boolean fixedCostFromExpenses,
            int activeProfessionals,
            BigDecimal sellableHoursPerMonth,
            BigDecimal fixedCostPerHour,
            BigDecimal averageCommissionPercent,
            Settings settings) {
    }

    public record ServicePricing(
            Long serviceId,
            String name,
            int plannedMinutes,
            Integer realAverageMinutes,
            int minutesUsed,
            BigDecimal currentPrice,
            BigDecimal materialCost,
            BigDecimal fixedCostShare,
            BigDecimal directCost,
            BigDecimal variablePercent,
            BigDecimal breakEvenPrice,
            BigDecimal suggestedPrice,
            BigDecimal currentProfit,
            BigDecimal currentMarginPercent,
            BigDecimal profitPerHour,
            Health health) {
    }

    public record Result(Basis basis, List<ServicePricing> services) {
    }

    private final SalonService salonService;
    private final ServiceItemRepository services;
    private final ProfessionalRepository professionals;
    private final ExpenseRepository expenses;
    private final AppointmentRepository appointments;
    private final Clock clock;

    public PricingService(SalonService salonService, ServiceItemRepository services, ProfessionalRepository professionals,
                          ExpenseRepository expenses, AppointmentRepository appointments, Clock clock) {
        this.salonService = salonService;
        this.services = services;
        this.professionals = professionals;
        this.expenses = expenses;
        this.appointments = appointments;
        this.clock = clock;
    }

    @Transactional
    public Settings updateSettings(Settings s) {
        Salon salon = salonService.current();
        salon.setCardFeePercent(s.cardFeePercent());
        salon.setTargetMarginPercent(s.targetMarginPercent());
        salon.setOccupancyPercent(s.occupancyPercent());
        salon.setFixedMonthlyCost(s.fixedMonthlyCost());
        return settings(salon);
    }

    @Transactional(readOnly = true)
    public Result calculate() {
        Salon salon = salonService.current();
        LocalDate today = LocalDate.now(clock);
        LocalDate from = today.minusDays(HISTORY_DAYS);

        // custo fixo mensal: informado ou média mensal das despesas dos últimos 3 meses
        boolean fromExpenses = salon.getFixedMonthlyCost() == null;
        BigDecimal monthlyFixed = fromExpenses
                ? monthlyAverage(expenses.findByDateBetweenOrderByDateDesc(from, today), today)
                : salon.getFixedMonthlyCost();

        List<Professional> active = professionals.findByActiveTrueOrderByName();
        double hoursPerWeek = salon.getHours().stream().mapToLong(DayHours::workMinutes).sum() / 60.0;
        double sellable = hoursPerWeek * WEEKS_PER_MONTH * Math.max(active.size(), 1)
                * salon.getOccupancyPercent().doubleValue() / 100;
        BigDecimal sellableHours = BigDecimal.valueOf(sellable).setScale(1, RoundingMode.HALF_UP);
        BigDecimal fixedPerHour = sellable > 0
                ? monthlyFixed.divide(BigDecimal.valueOf(sellable), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal avgCommission = active.isEmpty() ? BigDecimal.ZERO
                : active.stream().map(Professional::getCommissionPercent).reduce(BigDecimal.ZERO, BigDecimal::add)
                        .divide(BigDecimal.valueOf(active.size()), 2, RoundingMode.HALF_UP);

        Map<Long, Double> realMinutes = appointments
                .findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(from.atStartOfDay(), today.plusDays(1).atStartOfDay())
                .stream()
                .filter(a -> a.getStatus() == AppointmentStatus.DONE && a.realMinutes() != null && a.realMinutes() > 0)
                .collect(Collectors.groupingBy(a -> a.getService().getId(), Collectors.averagingLong(Appointment::realMinutes)));

        BigDecimal variablePercent = avgCommission.add(salon.getCardFeePercent());
        List<ServicePricing> result = services.findAllByOrderByName().stream()
                .filter(ServiceItem::isActive)
                .map(s -> price(s, realMinutes.get(s.getId()), fixedPerHour, variablePercent, salon.getTargetMarginPercent()))
                .toList();

        return new Result(new Basis(monthlyFixed, fromExpenses, active.size(), sellableHours, fixedPerHour, avgCommission,
                settings(salon)), result);
    }

    /**
     * Média mensal só sobre os meses que existem de histórico (1 a 3), para não diluir as despesas
     * de um salão novo como se ele tivesse 3 meses de dados.
     */
    static BigDecimal monthlyAverage(List<Expense> list, LocalDate today) {
        if (list.isEmpty()) {
            return BigDecimal.ZERO;
        }
        LocalDate first = list.stream().map(Expense::getDate).min(LocalDate::compareTo).orElse(today);
        long months = Math.min(3, Math.max(1, (long) Math.ceil(ChronoUnit.DAYS.between(first, today) / 30.4)));
        return list.stream().map(Expense::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(months), 2, RoundingMode.HALF_UP);
    }

    static ServicePricing price(ServiceItem s, Double realAvg, BigDecimal fixedPerHour, BigDecimal variablePercent,
                                BigDecimal marginPercent) {
        Integer real = realAvg != null ? (int) Math.round(realAvg) : null;
        // usa o tempo real quando ele é maior que o previsto: é o tempo que de fato ocupa a cadeira
        int minutes = real != null ? Math.max(real, s.getDurationMinutes()) : s.getDurationMinutes();
        BigDecimal fixedShare = fixedPerHour.multiply(BigDecimal.valueOf(minutes)).divide(BigDecimal.valueOf(60), 2, RoundingMode.HALF_UP);
        BigDecimal direct = s.getCost().add(fixedShare);

        BigDecimal variable = variablePercent.divide(HUNDRED, 6, RoundingMode.HALF_UP);
        BigDecimal margin = marginPercent.divide(HUNDRED, 6, RoundingMode.HALF_UP);
        BigDecimal breakEven = divideOrNull(direct, BigDecimal.ONE.subtract(variable));
        BigDecimal suggested = divideOrNull(direct, BigDecimal.ONE.subtract(variable).subtract(margin));

        BigDecimal price = s.getPrice();
        BigDecimal profit = price.subtract(direct).subtract(price.multiply(variable)).setScale(2, RoundingMode.HALF_UP);
        BigDecimal marginNow = price.signum() > 0
                ? profit.multiply(HUNDRED).divide(price, 1, RoundingMode.HALF_UP)
                : null;
        BigDecimal perHour = profit.multiply(BigDecimal.valueOf(60)).divide(BigDecimal.valueOf(minutes), 2, RoundingMode.HALF_UP);

        Health health;
        if (price.signum() <= 0) {
            health = Health.NO_PRICE;
        } else if (profit.signum() < 0) {
            health = Health.LOSS;
        } else if (marginNow.compareTo(marginPercent) < 0) {
            health = Health.LOW;
        } else {
            health = Health.HEALTHY;
        }

        return new ServicePricing(s.getId(), s.getName(), s.getDurationMinutes(), real, minutes, price, s.getCost(),
                fixedShare, direct, variablePercent, round(breakEven, false), round(suggested, true), profit, marginNow,
                perHour, health);
    }

    /** Divisor ≤ 5% significa que comissão + taxas + margem passam de 95%: não há preço possível. */
    private static BigDecimal divideOrNull(BigDecimal value, BigDecimal divisor) {
        // arredonda para cima: o preço mínimo nunca pode ficar 1 centavo abaixo do custo
        return divisor.compareTo(new BigDecimal("0.05")) <= 0 ? null : value.divide(divisor, 2, RoundingMode.CEILING);
    }

    /** Preço sugerido arredondado para cima de R$ 5 em R$ 5 (preço "redondo"); mínimo só centavos. */
    private static BigDecimal round(BigDecimal v, boolean toFive) {
        if (v == null) {
            return null;
        }
        if (!toFive) {
            return v.setScale(2, RoundingMode.CEILING);
        }
        return v.divide(BigDecimal.valueOf(5), 0, RoundingMode.CEILING).multiply(BigDecimal.valueOf(5)).setScale(2);
    }

    private static Settings settings(Salon s) {
        return new Settings(s.getCardFeePercent(), s.getTargetMarginPercent(), s.getOccupancyPercent(), s.getFixedMonthlyCost());
    }
}
