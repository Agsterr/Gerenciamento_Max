package com.max.salao.catalog;

import java.math.BigDecimal;

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
        return professional.attends(category);
    }
}
