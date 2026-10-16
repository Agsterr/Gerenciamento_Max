package com.max.salao.booking;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
class WebConfig implements WebMvcConfigurer {

    private final PublicTenantInterceptor publicTenantInterceptor;

    WebConfig(PublicTenantInterceptor publicTenantInterceptor) {
        this.publicTenantInterceptor = publicTenantInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(publicTenantInterceptor).addPathPatterns("/api/public/salons/{slug}/**",
                "/api/public/salons/{slug}");
    }
}
