package com.max.salao.catalog;

import java.math.BigDecimal;
import java.math.RoundingMode;

import java.util.HashSet;
import java.util.Set;

import com.max.salao.professional.Professional;
import com.max.salao.shared.TenantEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import org.hibernate.annotations.Fetch;
import org.hibernate.annotations.FetchMode;
import lombok.Getter;
import lombok.Setter;

/** Serviço oferecido pelo salão (corte, escova, manicure...). */
@Getter
@Setter
@Entity
public class ServiceItem extends TenantEntity {

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(nullable = false)
    private int durationMinutes;

    @Column(nullable = false)
    private BigDecimal price;

    /** Custo médio de material por atendimento (usado no cálculo de lucro). */
    @Column(nullable = false)
    private BigDecimal cost = BigDecimal.ZERO;

    private boolean active = true;

    /** Agrupa os serviços na tela de agendamento e no portfólio (Cabelo, Unhas...). Vazio = "Outros". */
    @Column(length = 40)
    private String category;

    /** Profissionais que fazem este serviço. Vazio = qualquer um. */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "service_professional", joinColumns = @JoinColumn(name = "service_id"))
    @Column(name = "professional_id")
    private Set<Long> professionalIds = new HashSet<>();

    /**
     * Lista explícita do serviço manda; sem lista, vale a especialidade do profissional
     * (serviço sem categoria qualquer um faz).
     */
    public boolean canBeDoneBy(Professional professional) {
        if (!professionalIds.isEmpty()) {
            return professionalIds.contains(professional.getId());
        }
        if (isKit()) {
            // pacote: quem faz todos os serviços dele
            return kitItems.stream().allMatch(i -> i.canBeDoneBy(professional));
        }
        return professional.attends(category);
    }

    /** Pacote (kit): desconto em % sobre a soma dos serviços que o formam. */
    private BigDecimal kitDiscountPercent;

    @ManyToMany(fetch = FetchType.EAGER)
    @Fetch(FetchMode.SUBSELECT)
    @JoinTable(name = "service_kit_item", joinColumns = @JoinColumn(name = "kit_id"),
            inverseJoinColumns = @JoinColumn(name = "service_id"))
    private Set<ServiceItem> kitItems = new HashSet<>();

    public boolean isKit() {
        return !kitItems.isEmpty();
    }

    /** Soma dos preços dos serviços do pacote (sem desconto). */
    public BigDecimal kitFullPrice() {
        return kitItems.stream().map(ServiceItem::getPrice).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Preço, duração e custo do pacote saem dos serviços que o formam. */
    public void recomputeKit() {
        if (!isKit()) {
            return;
        }
        BigDecimal pct = kitDiscountPercent == null ? BigDecimal.ZERO : kitDiscountPercent;
        price = kitFullPrice().multiply(BigDecimal.valueOf(100).subtract(pct))
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        durationMinutes = kitItems.stream().mapToInt(ServiceItem::getDurationMinutes).sum();
        cost = kitItems.stream().map(ServiceItem::getCost).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
