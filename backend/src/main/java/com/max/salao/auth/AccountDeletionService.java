package com.max.salao.auth;

import java.util.List;

import com.max.salao.portfolio.MediaStorage;
import com.max.salao.shared.NotFoundException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Exclusão de conta exigida pela App Store (5.1.1(v)) e pelo Google Play.
 * Se for o último dono, o salão e todos os seus dados são apagados definitivamente.
 */
@Service
public class AccountDeletionService {

    /** Ordem respeita as chaves estrangeiras. */
    private static final String[] TENANT_TABLES = {
            "notification", "push_device", "user_reminder_rule", "portfolio_photo", "stock_movement", "appointment", "expense", "product", "customer", "promotion", "service_item", "professional"};

    private final AppUserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final MediaStorage media;
    private final JdbcTemplate jdbc;

    public AccountDeletionService(AppUserRepository users, PasswordEncoder passwordEncoder, JdbcTemplate jdbc,
                                  MediaStorage media) {
        this.media = media;
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jdbc = jdbc;
    }

    /** @return {@code true} se o salão inteiro foi apagado */
    @Transactional
    public boolean delete(Long userId, String password) {
        AppUser user = users.findById(userId).orElseThrow(() -> new NotFoundException("Usuário não encontrado"));
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new BadCredentialsException("Senha incorreta");
        }
        Long salonId = user.getSalonId();
        boolean lastOwner = user.getRole() == Role.OWNER && users.findBySalonIdOrderByName(salonId).stream()
                .noneMatch(u -> !u.getId().equals(userId) && u.getRole() == Role.OWNER && u.isActive());

        if (!lastOwner) {
            users.delete(user);
            return false;
        }
        // fotos do portfólio saem também do R2/disco
        List<String> keys = jdbc.queryForList(
                "SELECT image_key FROM portfolio_photo WHERE tenant_id = ? UNION ALL SELECT thumb_key FROM portfolio_photo WHERE tenant_id = ?",
                String.class, salonId, salonId);
        keys.forEach(media::delete);
        for (String table : TENANT_TABLES) {
            jdbc.update("DELETE FROM " + table + " WHERE tenant_id = ?", salonId);
        }
        jdbc.update("DELETE FROM app_user WHERE salon_id = ?", salonId);
        jdbc.update("DELETE FROM salon WHERE id = ?", salonId);
        return true;
    }
}
