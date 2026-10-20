package com.max.salao.plan;

import com.max.salao.shared.TenantContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Salão com teste/plano vencido fica só para consulta: barra criar e alterar no painel e os
 * agendamentos e remarcações online. Ler, cancelar, entrar e excluir a conta continuam liberados.
 */
@Component
public class PlanInterceptor implements HandlerInterceptor {

    private final PlanService plans;

    public PlanInterceptor(PlanService plans) {
        this.plans = plans;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if ("GET".equals(request.getMethod()) || "HEAD".equals(request.getMethod()) || "OPTIONS".equals(request.getMethod())) {
            return true;
        }
        if (TenantContext.get().equals(TenantContext.NONE)) {
            return true;
        }
        String path = request.getRequestURI().substring(request.getContextPath().length());
        if (path.startsWith("/api/public/")) {
            boolean changesAgenda = path.endsWith("/bookings") || path.endsWith("/reschedule");
            if (changesAgenda) {
                plans.requireActive(true);
            }
            return true;
        }
        boolean alwaysAllowed = path.startsWith("/api/me/") || path.equals("/api/notifications/read") || path.endsWith("/cancel")
                || path.startsWith("/api/reminders/");
        if (!alwaysAllowed) {
            plans.requireActive(false);
        }
        return true;
    }
}
