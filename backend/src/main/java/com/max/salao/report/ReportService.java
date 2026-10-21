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
import com.max.salao.expense.ExpenseCategories;
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
            List<LowStock> lowStock,
            BigDecimal fixedExpenses,
            BigDecimal variableExpenses,
            Map<String, BigDecimal> fixedByCategory,
            Map<String, BigDecimal> variableByCategory,
            Rework rework,
            List<ProductReport> products) {
    }

    /** Refações do período: atendimentos sem cobrança que só geraram custo. */
    public record Rework(long count, BigDecimal materialCost, BigDecimal productsCost, BigDecimal totalCost,
                         List<ReworkItem> items) {
    }

    public record ReworkItem(Long appointmentId, java.time.LocalDateTime startAt, String customer, String service,
                             String professional, BigDecimal cost) {
    }

    /** Movimento de cada produto no período e situação atual do estoque. */
    public record ProductReport(Long id, String name, String unit,
                                BigDecimal soldQuantity, BigDecimal salesRevenue, BigDecimal soldCost, BigDecimal salesProfit,
                                BigDecimal usedQuantity, BigDecimal usedCost,
                                BigDecimal lostQuantity, BigDecimal lostCost,
                                BigDecimal purchasedQuantity, BigDecimal purchasedCost,
                                BigDecimal stock, BigDecimal stockValue, BigDecimal costPrice, BigDecimal salePrice,
                                BigDecimal markupPercent, boolean lowStock) {
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

        // refação não entra no ticket médio (não houve cobrança)
        long paid = done.stream().filter(a -> !a.isRework()).count();
        List<Expense> fixed = expenses.stream().filter(e -> ExpenseCategories.isFixed(e.getCategory())).toList();
        List<Expense> variable = expenses.stream().filter(e -> !ExpenseCategories.isFixed(e.getCategory())).toList();

        return new Summary(from, to,
                servicesRevenue, productSales, revenue,
                materialCost, usedCost, soldCost, commissions, expenseTotal, costs, revenue.subtract(costs),
                done.size(),
                count(all, AppointmentStatus.CANCELED),
                count(all, AppointmentStatus.NO_SHOW),
                all.stream().filter(a -> a.getSource() == Appointment.Source.ONLINE).count(),
                paid == 0 ? BigDecimal.ZERO
                        : servicesRevenue.divide(BigDecimal.valueOf(paid), 2, RoundingMode.HALF_UP),
                avg(done.stream().map(a -> (long) a.plannedMinutes()).toList()),
                avg(done.stream().map(Appointment::realMinutes).toList()),
                ranking(done, a -> a.getProfessional().getName()),
                ranking(done, a -> a.getService().getName()),
                expenses.stream().collect(Collectors.groupingBy(Expense::getCategory,
                        Collectors.reducing(BigDecimal.ZERO, Expense::getAmount, BigDecimal::add))),
                products.findAllByOrderByName().stream()
                        .filter(p -> p.isActive() && p.isLowStock())
                        .map(ReportService::lowStock)
                        .toList(),
                sum(fixed, Expense::getAmount),
                sum(variable, Expense::getAmount),
                byCategory(fixed),
                byCategory(variable),
                rework(done, moves),
                productReport(moves));
    }

    private static Map<String, BigDecimal> byCategory(List<Expense> expenses) {
        return expenses.stream().collect(Collectors.groupingBy(Expense::getCategory, java.util.TreeMap::new,
                Collectors.reducing(BigDecimal.ZERO, Expense::getAmount, BigDecimal::add)));
    }

    private static Rework rework(List<Appointment> done, List<StockMovement> moves) {
        List<Appointment> reworks = done.stream().filter(Appointment::isRework).toList();
        Map<Long, BigDecimal> usedByAppointment = moves.stream()
                .filter(m -> m.getType() == StockMovement.Type.USE && m.getAppointmentId() != null)
                .collect(Collectors.groupingBy(StockMovement::getAppointmentId,
                        Collectors.reducing(BigDecimal.ZERO, StockMovement::totalCost, BigDecimal::add)));
        List<ReworkItem> items = reworks.stream()
                .map(a -> new ReworkItem(a.getId(), a.getStartAt(), a.getCustomer().getName(), a.getService().getName(),
                        a.getProfessional().getName(),
                        a.getServiceCost().add(usedByAppointment.getOrDefault(a.getId(), BigDecimal.ZERO))))
                .toList();
        BigDecimal material = sum(reworks, Appointment::getServiceCost);
        BigDecimal products = reworks.stream().map(a -> usedByAppointment.getOrDefault(a.getId(), BigDecimal.ZERO))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        return new Rework(reworks.size(), material, products, material.add(products), items);
    }

    private List<ProductReport> productReport(List<StockMovement> moves) {
        Map<Long, List<StockMovement>> byProduct = moves.stream()
                .collect(Collectors.groupingBy(m -> m.getProduct().getId()));
        return products.findAllByOrderByName().stream()
                .filter(p -> p.isActive() || byProduct.containsKey(p.getId()))
                .map(p -> {
                    List<StockMovement> m = byProduct.getOrDefault(p.getId(), List.of());
                    List<StockMovement> sales = ofType(m, StockMovement.Type.SALE);
                    List<StockMovement> used = ofType(m, StockMovement.Type.USE);
                    List<StockMovement> lost = ofType(m, StockMovement.Type.LOSS);
                    List<StockMovement> bought = ofType(m, StockMovement.Type.IN);
                    BigDecimal revenue = sum(sales, StockMovement::totalPrice);
                    BigDecimal soldCost = sum(sales, StockMovement::totalCost);
                    return new ProductReport(p.getId(), p.getName(), p.getUnit(),
                            sum(sales, StockMovement::getQuantity), revenue, soldCost, revenue.subtract(soldCost),
                            sum(used, StockMovement::getQuantity), sum(used, StockMovement::totalCost),
                            sum(lost, StockMovement::getQuantity), sum(lost, StockMovement::totalCost),
                            sum(bought, StockMovement::getQuantity), sum(bought, StockMovement::totalCost),
                            p.getStock(), p.getStock().multiply(p.getCostPrice()).setScale(2, RoundingMode.HALF_UP),
                            p.getCostPrice(), p.getSalePrice(), p.getMarkupPercent(), p.isLowStock());
                })
                .toList();
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
