package com.max.salao.catalog;

import java.math.BigDecimal;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
}
