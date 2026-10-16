package com.max.salao.expense;

import java.math.BigDecimal;
import java.time.LocalDate;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

/** Custo fixo/variável do salão: aluguel, luz, salários, marketing... */
@Getter
@Setter
@Entity
public class Expense extends TenantEntity {

    @Column(nullable = false)
    private String description;

    @Column(nullable = false)
    private String category;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(nullable = false)
    private LocalDate date;
}
