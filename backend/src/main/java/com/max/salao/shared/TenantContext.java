package com.max.salao.shared;

/**
 * Guarda o salão (tenant) da requisição atual. Preenchido pelo {@code TenantFilter}
 * (usuários logados) ou pelo {@code PublicTenantInterceptor} (páginas públicas de agendamento).
 */
public final class TenantContext {

    /** Valor usado quando não há tenant: não corresponde a nenhum salão, então nada vaza. */
    public static final Long NONE = 0L;

    private static final ThreadLocal<Long> CURRENT = new ThreadLocal<>();

    private TenantContext() {
    }

    public static void set(Long tenantId) {
        CURRENT.set(tenantId);
    }

    public static Long get() {
        Long tenantId = CURRENT.get();
        return tenantId != null ? tenantId : NONE;
    }

    public static void clear() {
        CURRENT.remove();
    }
}
