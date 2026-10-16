package com.max.salao.platform;

import com.max.salao.auth.AppUser;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.auth.Role;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Cria ou atualiza no boot o administrador da plataforma a partir de
 * {@code PLATFORM_ADMIN_EMAIL} / {@code PLATFORM_ADMIN_PASSWORD}. Sem as duas variáveis, não faz nada.
 */
@Component
class PlatformAdminInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PlatformAdminInitializer.class);

    private final AppUserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final String email;
    private final String password;

    PlatformAdminInitializer(AppUserRepository users, PasswordEncoder passwordEncoder,
                             @Value("${app.platform-admin.email:}") String email,
                             @Value("${app.platform-admin.password:}") String password) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.email = email == null ? "" : email.trim().toLowerCase();
        this.password = password == null ? "" : password;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (email.isBlank() || password.isBlank()) {
            return;
        }
        if (password.length() < 8) {
            log.warn("PLATFORM_ADMIN_PASSWORD precisa ter pelo menos 8 caracteres; administrador não criado.");
            return;
        }
        AppUser admin = users.findByEmailIgnoreCase(email).orElse(null);
        if (admin != null && admin.getRole() != Role.PLATFORM_ADMIN) {
            log.warn("PLATFORM_ADMIN_EMAIL {} já pertence a um usuário de salão; administrador não criado.", email);
            return;
        }
        if (admin == null) {
            admin = new AppUser();
            admin.setEmail(email);
            admin.setName("Administrador da plataforma");
            admin.setRole(Role.PLATFORM_ADMIN);
            log.info("Administrador da plataforma criado: {}", email);
        }
        if (admin.getPasswordHash() == null || !passwordEncoder.matches(password, admin.getPasswordHash())) {
            admin.setPasswordHash(passwordEncoder.encode(password));
        }
        admin.setActive(true);
        admin.setBlocked(false);
        users.save(admin);
    }
}
