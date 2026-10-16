package com.max.salao.report;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.expense.Expense;
import com.max.salao.expense.ExpenseRepository;
import com.max.salao.product.Product;
import com.max.salao.product.ProductRepository;
import com.max.salao.product.StockMovement;
import com.max.salao.product.StockMovementRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Resumo financeiro e operacional do período. Os volumes de um salão são pequenos,
 * então agregamos em memória — simples de ler e de manter.
 */
@Service
public class ReportService {

    public record Summary(
            LocalDate from,
            LocalDate to,
            BigDecimal servicesRevenue,
            BigDecimal productSalesRevenue,
            BigDecimal totalRevenue,
            BigDecimal serviceMaterialCost,
            BigDecimal productsUsedCost,
            BigDecimal productsSoldCost,
            BigDecimal commissions,
            BigDecimal expenses,
            BigDecimal totalCosts,
            BigDecimal profit,
            long appointmentsDone,
            long appointmentsCanceled,
            long appointmentsNoShow,
            long onlineBookings,
            BigDecimal averageTicket,
            Double averageEstimatedMinutes,
            Double averageRealMinutes,
            List<Ranking> byProfessional,
            List<Ranking> byService,
            Map<String, BigDecimal> expensesByCategory,
            List<LowStock> lowStock) {
    }

    public record Ranking(String name, long count, BigDecimal revenue, BigDecimal commission, Double avgRealMinutes) {
    }

    public record LowStock(Long id, String name, BigDecimal stock, BigDecimal minStock, String unit) {
    }

    private final AppointmentRepository appointments;
    private final StockMovementRepository movements;
    private final ExpenseRepository expenseRepository;
    private final ProductRepository products;

    public ReportService(AppointmentRepository appointments, StockMovementRepository movements,
                         ExpenseRepository expenseRepository, ProductRepository products) {
        this.appointments = appointments;
        this.movements = movements;
        this.expenseRepository = expenseRepository;
        this.products = products;
    }

    @Transactional(readOnly = true)
    public Summary summary(LocalDate from, LocalDate to) {
        List<Appointment> all = appointments.findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(
                from.atStartOfDay(), to.plusDays(1).atStartOfDay());
        List<Appointment> done = all.stream().filter(a -> a.getStatus() == AppointmentStatus.DONE).toList();
        List<StockMovement> moves = movements.findByCreatedAtBetweenOrderByCreatedAtDesc(
                from.atStartOfDay(), to.plusDays(1).atStartOfDay());
        List<Expense> expenses = expenseRepository.findByDateBetweenOrderByDateDesc(from, to);

        BigDecimal servicesRevenue = sum(done, Appointment::getPrice);
        BigDecimal productSales = sum(ofType(moves, StockMovement.Type.SALE), StockMovement::totalPrice);
        BigDecimal materialCost = sum(done, Appointment::getServiceCost);
        BigDecimal usedCost = sum(ofType(moves, StockMovement.Type.USE), StockMovement::totalCost)
                .add(sum(ofType(moves, StockMovement.Type.LOSS), StockMovement::totalCost));
        BigDecimal soldCost = sum(ofType(moves, StockMovement.Type.SALE), StockMovement::totalCost);
        BigDecimal commissions = sum(done, Appointment::getCommissionAmount);
        BigDecimal expenseTotal = sum(expenses, Expense::getAmount);

        BigDecimal revenue = servicesRevenue.add(productSales);
        BigDecimal costs = materialCost.add(usedCost).add(soldCost).add(commissions).add(expenseTotal);

        return new Summary(from, to,
                servicesRevenue, productSales, revenue,
                materialCost, usedCost, soldCost, commissions, expenseTotal, costs, revenue.subtract(costs),
                done.size(),
                count(all, AppointmentStatus.CANCELED),
                count(all, AppointmentStatus.NO_SHOW),
                all.stream().filter(a -> a.getSource() == Appointment.Source.ONLINE).count(),
                done.isEmpty() ? BigDecimal.ZERO
                        : servicesRevenue.divide(BigDecimal.valueOf(done.size()), 2, RoundingMode.HALF_UP),
                avg(done.stream().map(a -> (long) a.getService().getDurationMinutes()).toList()),
                avg(done.stream().map(Appointment::realMinutes).toList()),
                ranking(done, a -> a.getProfessional().getName()),
                ranking(done, a -> a.getService().getName()),
                expenses.stream().collect(Collectors.groupingBy(Expense::getCategory,
                        Collectors.reducing(BigDecimal.ZERO, Expense::getAmount, BigDecimal::add))),
                products.findAllByOrderByName().stream()
                        .filter(p -> p.isActive() && p.isLowStock())
                        .map(ReportService::lowStock)
                        .toList());
    }

    private static List<Ranking> ranking(List<Appointment> done, Function<Appointment, String> key) {
        return done.stream().collect(Collectors.groupingBy(key)).entrySet().stream()
                .map(e -> new Ranking(e.getKey(), e.getValue().size(),
                        sum(e.getValue(), Appointment::getPrice),
                        sum(e.getValue(), Appointment::getCommissionAmount),
                        avg(e.getValue().stream().map(Appointment::realMinutes).toList())))
                .sorted(Comparator.comparing(Ranking::revenue).reversed())
                .toList();
    }

    private static LowStock lowStock(Product p) {
        return new LowStock(p.getId(), p.getName(), p.getStock(), p.getMinStock(), p.getUnit());
    }

    private static List<StockMovement> ofType(List<StockMovement> moves, StockMovement.Type type) {
        return moves.stream().filter(m -> m.getType() == type).toList();
    }

    private static long count(List<Appointment> list, AppointmentStatus status) {
        return list.stream().filter(a -> a.getStatus() == status).count();
    }

    private static <T> BigDecimal sum(List<T> list, Function<T, BigDecimal> value) {
        return list.stream().map(value).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static Double avg(List<Long> values) {
        return values.stream().filter(v -> v != null).mapToLong(Long::longValue).average().stream().boxed()
                .findFirst().orElse(null);
    }
}
