package com.max.salao.professional;

import java.math.BigDecimal;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Professional extends TenantEntity {

    @Column(nullable = false)
    private String name;

    private String phone;

    /** Percentual de comissão sobre o valor do serviço (0–100). */
    @Column(nullable = false)
    private BigDecimal commissionPercent = BigDecimal.ZERO;

    private boolean active = true;
}
