package com.max.salao.product;

import java.math.BigDecimal;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Product extends TenantEntity {

    @Column(nullable = false)
    private String name;

    /** Custo da última entrada no estoque. */
    @Column(nullable = false)
    private BigDecimal costPrice = BigDecimal.ZERO;

    /** Preço de venda para o cliente (0 = só uso interno). */
    @Column(nullable = false)
    private BigDecimal salePrice = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal stock = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal minStock = BigDecimal.ZERO;

    @Column(nullable = false)
    private String unit = "un";

    private boolean active = true;

    public boolean isLowStock() {
        return stock.compareTo(minStock) <= 0;
    }
}
