package com.max.salao.promotion;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.shared.TenantEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import lombok.Getter;
import lombok.Setter;

/** Desconto em % nos serviços escolhidos (vazio = todos) para horários entre {@code startsOn} e {@code endsOn}. */
@Getter
@Setter
@Entity
public class Promotion extends TenantEntity {

    @Column(nullable = false, length = 80)
    private String name;

    @Column(length = 300)
    private String description;

    @Column(nullable = false)
    private BigDecimal discountPercent;

    @Column(nullable = false)
    private LocalDate startsOn;

    @Column(nullable = false)
    private LocalDate endsOn;

    private boolean active = true;

    /** Avisar os clientes no celular (app do cliente). */
    private boolean notifyCustomers = true;

    /** Quando o push desta promoção saiu (nulo = ainda não). */
    private LocalDateTime notifiedAt;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "promotion_service", joinColumns = @JoinColumn(name = "promotion_id"))
    @Column(name = "service_id")
    private Set<Long> serviceIds = new HashSet<>();

    /** Vale para este serviço num horário deste dia. */
    public boolean appliesTo(ServiceItem service, LocalDate day) {
        return active && !day.isBefore(startsOn) && !day.isAfter(endsOn) && covers(service);
    }

    /** "Todos os serviços" não inclui pacotes (eles já têm desconto próprio); escolhido na lista, inclui. */
    public boolean covers(ServiceItem service) {
        return serviceIds.isEmpty() ? !service.isKit() : serviceIds.contains(service.getId());
    }

    public BigDecimal apply(BigDecimal price) {
        return price.multiply(BigDecimal.valueOf(100).subtract(discountPercent))
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }
}
