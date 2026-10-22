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

    /** Aparece na vitrine do cliente (se estiver ativo e tiver preço de venda). */
    private boolean showcase = true;

    /** Quanto o salão quer ganhar em cima do custo, em % (só referência para o preço de venda). */
    private BigDecimal markupPercent;

    /** Lucro por unidade vendida no preço atual. */
    public BigDecimal unitProfit() {
        return salePrice.subtract(costPrice);
    }

    public boolean isLowStock() {
        return stock.compareTo(minStock) <= 0;
    }
}
