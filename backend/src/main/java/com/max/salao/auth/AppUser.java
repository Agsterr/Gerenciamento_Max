package com.max.salao.auth;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Usuário do painel. Não usa {@code @TenantId} porque o login precisa achar o usuário
 * pelo e-mail antes de sabermos o salão.
 */
@Getter
@Setter
@Entity
@Table(name = "app_user")
public class AppUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Nulo só para {@link Role#PLATFORM_ADMIN}. */
    private Long salonId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    private boolean active = true;

    /** Agenda que o usuário acompanha nos lembretes dele (nulo = todos os profissionais). */
    private Long professionalId;

    /** Bloqueado pelo administrador da plataforma. */
    private boolean blocked;
    private String blockedReason;
    private LocalDateTime blockedAt;
}
