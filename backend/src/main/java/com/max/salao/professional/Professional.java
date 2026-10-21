package com.max.salao.professional;

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

    /** Categorias de serviço que atende (Cabelo, Unhas...). Vazio = atende qualquer categoria. */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "professional_category", joinColumns = @JoinColumn(name = "professional_id"))
    @Column(name = "category", length = 40)
    private Set<String> categories = new HashSet<>();

    public boolean attends(String category) {
        return categories.isEmpty() || category == null || categories.stream().anyMatch(c -> c.equalsIgnoreCase(category));
    }
}
