package com.max.salao.customer;

import java.time.LocalDateTime;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
public class Customer extends TenantEntity {

    @Column(nullable = false)
    private String name;

    /** Telefone (só dígitos) identifica o cliente dentro do salão. */
    @Column(nullable = false)
    private String phone;

    private String email;
    private String notes;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    /** Última vez que abriu a página do salão no app do cliente. */
    private LocalDateTime lastSeenAt;

    /** Aceita avisos de promoção no celular (nulo = ainda não escolheu, vale como ligado). */
    private Boolean promoNotifications;

    public static String normalizePhone(String phone) {
        return phone == null ? null : phone.replaceAll("\\D", "");
    }
}
