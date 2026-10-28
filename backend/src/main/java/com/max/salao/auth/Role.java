package com.max.salao.auth;

public enum Role {
    /** Dono do salão: acesso total, inclusive financeiro. */
    OWNER,
    /** Recepção/profissional: agenda, clientes e produtos. */
    STAFF,
    /** Administrador da plataforma (fora dos salões): bloqueia salões/usuários e gerencia os APKs. */
    PLATFORM_ADMIN,
    /** Representante: indica salões por um link e acompanha as comissões (fora dos salões). */
    REPRESENTATIVE
}
