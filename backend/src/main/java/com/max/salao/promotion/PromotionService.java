package com.max.salao.promotion;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import com.max.salao.catalog.ServiceItem;
import org.springframework.stereotype.Service;

@Service
public class PromotionService {

    /** Preço do serviço num dia, com a melhor promoção que vale (se houver). */
    public record Price(BigDecimal price, BigDecimal discount, Promotion promotion) {
    }

    private final PromotionRepository promotions;

    public PromotionService(PromotionRepository promotions) {
        this.promotions = promotions;
    }

    /** Promoções ativas que ainda não acabaram (inclui as que começam depois). */
    public List<Promotion> current(LocalDate today) {
        return promotions.findByActiveTrueAndEndsOnGreaterThanEqualOrderByEndsOn(today);
    }

    public Optional<Promotion> best(List<Promotion> list, ServiceItem service, LocalDate day) {
        return list.stream().filter(p -> p.appliesTo(service, day))
                .max(Comparator.comparing(Promotion::getDiscountPercent));
    }

    public Price priceOn(ServiceItem service, LocalDate day) {
        return best(current(day), service, day)
                .map(p -> {
                    BigDecimal price = p.apply(service.getPrice());
                    return new Price(price, service.getPrice().subtract(price), p);
                })
                .orElse(new Price(service.getPrice(), BigDecimal.ZERO, null));
    }
}
