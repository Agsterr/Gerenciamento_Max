package com.max.salao.catalog;

import java.math.BigDecimal;

import java.util.HashSet;
import java.util.Set;

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

    public boolean canBeDoneBy(Long professionalId) {
        return professionalIds.isEmpty() || professionalIds.contains(professionalId);
    }
}
