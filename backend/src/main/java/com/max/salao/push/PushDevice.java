package com.max.salao.push;

import java.time.LocalDateTime;

import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.Getter;
import lombok.Setter;

/** Celular com o app do cliente que recebe push deste salão. */
@Getter
@Setter
@Entity
public class PushDevice extends TenantEntity {

    @Column(nullable = false, length = 512)
    private String token;

    /** Cliente identificado (código de agendamento ou nome + WhatsApp); nulo = só abriu o salão. */
    private Long customerId;

    /** Usuário do salão dono do celular (app de gestão); nulo = celular do app do cliente. */
    private Long userId;

    /** CLIENT (app do cliente) ou STAFF (app de gestão). */
    @Column(nullable = false, length = 10)
    private String app = "CLIENT";

    private boolean promoNotifications = true;

    @Column(nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();
}
