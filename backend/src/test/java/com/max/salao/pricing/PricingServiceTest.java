package com.max.salao.pricing;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.expense.Expense;
import org.junit.jupiter.api.Test;

class PricingServiceTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 16);

    @Test
    void averageUsesOnlyTheMonthsWithHistory() {
        var oneMonth = List.of(expense(3000, TODAY.minusDays(10)), expense(1230, TODAY.minusDays(2)));
        assertThat(PricingService.monthlyAverage(oneMonth, TODAY)).isEqualByComparingTo("4230.00");

        var threeMonths = List.of(expense(3000, TODAY.minusDays(85)), expense(3000, TODAY.minusDays(50)), expense(3000, TODAY));
        assertThat(PricingService.monthlyAverage(threeMonths, TODAY)).isEqualByComparingTo("3000.00");

        assertThat(PricingService.monthlyAverage(List.of(), TODAY)).isEqualByComparingTo("0");
    }

    @Test
    void lossWhenPriceDoesNotCoverCosts() {
        var p = PricingService.price(service(60, 30, 25), null, BigDecimal.TEN, BigDecimal.valueOf(44), BigDecimal.valueOf(20));
        assertThat(p.health()).isEqualTo(PricingService.Health.LOSS);
        assertThat(p.suggestedPrice()).isEqualByComparingTo("100.00"); // 35 / 0,36 = 97,23 → 100
    }

    @Test
    void usesRealDurationWhenLongerThanPlanned() {
        var p = PricingService.price(service(60, 100, 0), 90.0, BigDecimal.valueOf(20), BigDecimal.ZERO, BigDecimal.ZERO);
        assertThat(p.minutesUsed()).isEqualTo(90);
        assertThat(p.fixedCostShare()).isEqualByComparingTo("30.00");
    }

    @Test
    void noPriceWhenCommissionFeesAndMarginTakeEverything() {
        var p = PricingService.price(service(60, 100, 10), null, BigDecimal.TEN, BigDecimal.valueOf(70), BigDecimal.valueOf(30));
        assertThat(p.suggestedPrice()).isNull();
        assertThat(p.breakEvenPrice()).isNotNull();
    }

    private static Expense expense(int amount, LocalDate date) {
        var e = new Expense();
        e.setAmount(BigDecimal.valueOf(amount));
        e.setDate(date);
        e.setDescription("x");
        e.setCategory("x");
        return e;
    }

    private static ServiceItem service(int minutes, int price, int cost) {
        var s = new ServiceItem();
        s.setName("Serviço");
        s.setDurationMinutes(minutes);
        s.setPrice(BigDecimal.valueOf(price));
        s.setCost(BigDecimal.valueOf(cost));
        return s;
    }
}
