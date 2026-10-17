package com.max.salao.booking;

import com.max.salao.plan.PlanInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
class WebConfig implements WebMvcConfigurer {

    private final PublicTenantInterceptor publicTenantInterceptor;
    private final PlanInterceptor planInterceptor;

    WebConfig(PublicTenantInterceptor publicTenantInterceptor, PlanInterceptor planInterceptor) {
        this.publicTenantInterceptor = publicTenantInterceptor;
        this.planInterceptor = planInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(publicTenantInterceptor).addPathPatterns("/api/public/salons/{slug}/**",
                "/api/public/salons/{slug}");
        // depois do tenant definido (JWT ou slug): salão vencido só consulta
        registry.addInterceptor(planInterceptor).addPathPatterns("/api/**")
                .excludePathPatterns("/api/auth/**", "/api/platform/**", "/api/app/**");
    }
}
