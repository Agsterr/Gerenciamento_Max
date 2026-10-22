package com.max.salao.push;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.promotion.Promotion;
import com.max.salao.promotion.PromotionRepository;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.Money;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Manda o push das promoções que começaram (uma vez cada) para os celulares que aceitam avisos. */
@Service
public class PromotionPushService {

    private static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("dd/MM");

    private final PromotionRepository promotions;
    private final PushNotifier notifier;
    private final PushProperties props;
    private final ServiceItemRepository services;
    private final SalonService salons;
    private final java.time.Clock clock;

    public PromotionPushService(PromotionRepository promotions, PushNotifier notifier, PushProperties props,
                                ServiceItemRepository services, SalonService salons, java.time.Clock clock) {
        this.promotions = promotions;
        this.notifier = notifier;
        this.props = props;
        this.services = services;
        this.salons = salons;
        this.clock = clock;
    }

    /** Roda dentro do tenant já definido. Devolve quantos pushes saíram. */
    @Transactional
    public int sendDue() {
        LocalDate today = LocalDate.now(clock);
        List<Promotion> due = promotions.findByActiveTrueAndEndsOnGreaterThanEqualOrderByEndsOn(today).stream()
                .filter(p -> p.isNotifyCustomers() && p.getNotifiedAt() == null && !p.getStartsOn().isAfter(today))
                .toList();
        if (due.isEmpty()) {
            return 0;
        }
        if (!props.configured()) {
            return 0;
        }
        Salon salon = salons.current();
        List<ServiceItem> all = services.findByActiveTrueOrderByName();
        int queued = 0;
        for (Promotion p : due) {
            List<ServiceItem> covered = all.stream().filter(p::covers).toList();
            String title = "Promoção no " + salon.getName();
            String body = body(p, covered);
            Map<String, String> data = Map.of(
                    "type", "promo",
                    "slug", salon.getSlug(),
                    "promotionId", String.valueOf(p.getId()),
                    "serviceId", p.getServiceIds().isEmpty() ? "" : String.valueOf(p.getServiceIds().iterator().next()));
            // vai para a fila: o enviador entrega, tenta de novo se falhar e registra a confirmação
            queued += notifier.promotion("promo:" + p.getId(), title, body, data);
            p.setNotifiedAt(LocalDateTime.now(clock));
        }
        return queued;
    }

    /** "Corte de R$ 100,00 por R$ 80,00 e mais 2 · até 30/11". */
    static String body(Promotion p, List<ServiceItem> covered) {
        String until = " · até " + p.getEndsOn().format(DAY);
        if (covered.isEmpty()) {
            return p.getName() + ": " + p.getDiscountPercent().stripTrailingZeros().toPlainString() + "% de desconto" + until;
        }
        ServiceItem first = covered.get(0);
        String more = covered.size() > 1 ? " e mais " + (covered.size() - 1) : "";
        return first.getName() + " de " + Money.format(first.getPrice()) + " por " + Money.format(p.apply(first.getPrice()))
                + more + until;
    }
}
