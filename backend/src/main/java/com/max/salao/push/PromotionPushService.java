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
    private final PushDeviceRepository devices;
    private final ServiceItemRepository services;
    private final SalonService salons;
    private final PushSender sender;
    private final java.time.Clock clock;

    public PromotionPushService(PromotionRepository promotions, PushDeviceRepository devices,
                                ServiceItemRepository services, SalonService salons, PushSender sender,
                                java.time.Clock clock) {
        this.promotions = promotions;
        this.devices = devices;
        this.services = services;
        this.salons = salons;
        this.sender = sender;
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
        Salon salon = salons.current();
        List<PushDevice> targets = devices.findByPromoNotificationsTrue();
        List<ServiceItem> all = services.findByActiveTrueOrderByName();
        int sent = 0;
        for (Promotion p : due) {
            List<ServiceItem> covered = all.stream().filter(p::covers).toList();
            String title = "Promoção no " + salon.getName();
            String body = body(p, covered);
            Map<String, String> data = Map.of(
                    "type", "promo",
                    "slug", salon.getSlug(),
                    "promotionId", String.valueOf(p.getId()),
                    "serviceId", p.getServiceIds().isEmpty() ? "" : String.valueOf(p.getServiceIds().iterator().next()));
            for (PushDevice d : targets) {
                PushSender.Result r = sender.send(d.getToken(), title, body, data);
                if (r == PushSender.Result.DISABLED) {
                    return sent; // sem Firebase configurado: tenta de novo quando configurar
                }
                if (r == PushSender.Result.INVALID_TOKEN) {
                    devices.delete(d);
                } else if (r == PushSender.Result.SENT) {
                    sent++;
                }
            }
            p.setNotifiedAt(LocalDateTime.now(clock));
        }
        return sent;
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
