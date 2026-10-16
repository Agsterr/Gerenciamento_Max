package com.max.salao.product;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.ManyToOne;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class StockMovement extends TenantEntity {

    public enum Type {
        /** Compra/entrada no estoque. */
        IN,
        /** Venda ao cliente (gera receita). */
        SALE,
        /** Consumo em atendimento (gera custo). */
        USE,
        /** Perda/ajuste de inventário. */
        LOSS
    }

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Product product;

    private Long appointmentId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Type type;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(nullable = false)
    private BigDecimal unitCost;

    /** Preenchido apenas em vendas. */
    private BigDecimal unitPrice;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public BigDecimal totalCost() {
        return unitCost.multiply(quantity);
    }

    public BigDecimal totalPrice() {
        return unitPrice == null ? BigDecimal.ZERO : unitPrice.multiply(quantity);
    }
}
