package com.max.salao.security;

import java.nio.charset.StandardCharsets;
import java.util.List;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jose.jwk.source.ImmutableSecret;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, AccountStatusService statuses, ObjectMapper json)
            throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/auth/**", "/api/public/**", "/api/push/ack", "/api/asaas/webhook", "/actuator/health").permitAll()
                        // APK fora da loja: consulta/download públicos; o deploy confere o X-Deploy-Token
                        .requestMatchers(HttpMethod.GET, "/api/app/version", "/api/app/download/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/app/releases/deploy").permitAll()
                        .requestMatchers("/api/platform/**").hasRole("PLATFORM_ADMIN")
                        .requestMatchers("/api/representative/**").hasRole("REPRESENTATIVE")
                        .requestMatchers(HttpMethod.GET, "/api/me").authenticated()
                        // Gestão financeira e cadastros estruturais: só o dono
                        .requestMatchers("/api/reports/**", "/api/expenses/**", "/api/users/**", "/api/pricing/**").hasRole("OWNER")
                        .requestMatchers(HttpMethod.PUT, "/api/salon").hasRole("OWNER")
                        .requestMatchers("/api/billing/**").hasRole("OWNER")
                        .requestMatchers(HttpMethod.POST, "/api/professionals/**", "/api/services/**", "/api/promotions/**").hasRole("OWNER")
                        .requestMatchers(HttpMethod.PUT, "/api/professionals/**", "/api/services/**", "/api/promotions/**").hasRole("OWNER")
                        .requestMatchers(HttpMethod.DELETE, "/api/promotions/**").hasRole("OWNER")
                        // Demais rotas são do salão: o admin da plataforma não tem tenant
                        .anyRequest().hasAnyRole("OWNER", "STAFF"))
                .oauth2ResourceServer(o -> o.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())))
                .addFilterAfter(new AccountStatusFilter(statuses, json), BearerTokenAuthenticationFilter.class)
                .addFilterAfter(new TenantFilter(), AccountStatusFilter.class)
                .build();
    }

    private JwtAuthenticationConverter jwtAuthenticationConverter() {
        var authorities = new JwtGrantedAuthoritiesConverter();
        authorities.setAuthoritiesClaimName(JwtService.ROLE_CLAIM);
        authorities.setAuthorityPrefix("ROLE_");
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authorities);
        return converter;
    }

    @Bean
    SecretKey jwtKey(JwtProperties props) {
        byte[] bytes = props.secret().getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("app.jwt.secret precisa ter pelo menos 32 caracteres");
        }
        return new SecretKeySpec(bytes, "HmacSHA256");
    }

    @Bean
    JwtEncoder jwtEncoder(SecretKey jwtKey) {
        return new NimbusJwtEncoder(new ImmutableSecret<>(jwtKey));
    }

    @Bean
    JwtDecoder jwtDecoder(SecretKey jwtKey) {
        return NimbusJwtDecoder.withSecretKey(jwtKey).macAlgorithm(MacAlgorithm.HS256).build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(@Value("${app.cors.allowed-origins}") List<String> origins) {
        var config = new CorsConfiguration();
        config.setAllowedOrigins(origins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        var source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
