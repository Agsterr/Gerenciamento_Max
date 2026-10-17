package com.max.salao.booking;

import java.util.Map;

import com.max.salao.salon.SalonRepository;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.TenantContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;

/** Nas rotas públicas /api/public/salons/{slug}/** o tenant vem do slug da URL. */
@Component
class PublicTenantInterceptor implements HandlerInterceptor {

    private final SalonRepository salons;

    PublicTenantInterceptor(SalonRepository salons) {
        this.salons = salons;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        @SuppressWarnings("unchecked")
        var vars = (Map<String, String>) request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
        String slug = vars != null ? vars.get("slug") : null;
        if (slug != null) {
            // Salão bloqueado some das páginas públicas
            Long salonId = salons.findBySlug(slug)
                    .filter(s -> !s.isBlocked())
                    .orElseThrow(() -> new NotFoundException("Salão não encontrado"))
                    .getId();
            TenantContext.set(salonId);
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        TenantContext.clear();
    }
}
