package com.max.salao.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;

import com.max.salao.mail.MailProperties;
import com.max.salao.mail.MailSender;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.HtmlUtils;

/**
 * "Esqueci minha senha": manda por e-mail um link que vale 1 hora e um único uso. O token vai só no e-mail;
 * no banco fica o hash. A resposta é sempre a mesma, exista ou não a conta (não revela quem tem cadastro).
 */
@Service
public class PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);
    static final long VALID_MINUTES = 60;

    private final AppUserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbc;
    private final MailSender mail;
    private final MailProperties mailProps;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public PasswordResetService(AppUserRepository users, PasswordEncoder passwordEncoder, JdbcTemplate jdbc,
                                MailSender mail, MailProperties mailProps, Clock clock) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jdbc = jdbc;
        this.mail = mail;
        this.mailProps = mailProps;
        this.clock = clock;
    }

    @Transactional
    public void request(String email) {
        AppUser user = users.findByEmailIgnoreCase(email.trim())
                .filter(AppUser::isActive)
                .filter(u -> !u.isBlocked())
                // a senha do administrador da plataforma só muda no servidor
                .filter(u -> u.getRole() != Role.PLATFORM_ADMIN)
                .orElse(null);
        if (user == null) {
            return;
        }
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);

        jdbc.update("delete from password_reset where user_id = ? and used_at is null", user.getId());
        jdbc.update("insert into password_reset (user_id, token_hash, expires_at) values (?, ?, ?)", user.getId(),
                hash(token), LocalDateTime.now(clock).plusMinutes(VALID_MINUTES));

        String link = mailProps.siteUrl() + "/redefinir-senha?token=" + token;
        String first = HtmlUtils.htmlEscape(user.getName().split(" ")[0]);
        String text = "Olá, " + user.getName().split(" ")[0] + "!\n\n"
                + "Recebemos um pedido para redefinir a senha da sua conta no Salão Max. Abra o link abaixo (vale por 1 hora):\n\n"
                + link + "\n\nSe não foi você, ignore este e-mail: sua senha continua a mesma.";
        String html = "<p>Olá, " + first + "!</p>"
                + "<p>Recebemos um pedido para redefinir a senha da sua conta no <strong>Salão Max</strong>.</p>"
                + "<p><a href=\"" + link + "\" style=\"background:#E5267A;color:#fff;padding:12px 20px;border-radius:12px;"
                + "text-decoration:none;font-weight:bold\">Criar nova senha</a></p>"
                + "<p>O link vale por 1 hora. Se não foi você, ignore este e-mail: sua senha continua a mesma.</p>";
        try {
            mail.send(user.getEmail(), "Redefinir sua senha — Salão Max", html, text);
        } catch (MailSender.MailException e) {
            // não revela ao usuário se deu certo; o erro fica no log para o administrador
            log.error("Falha ao enviar e-mail de recuperação de senha: {}", e.getMessage());
        }
    }

    @Transactional
    public void reset(String token, String newPassword) {
        List<Long[]> rows = jdbc.query("""
                select id, user_id from password_reset
                where token_hash = ? and used_at is null and expires_at > ?""",
                (rs, i) -> new Long[] {rs.getLong(1), rs.getLong(2)}, hash(token), LocalDateTime.now(clock));
        if (rows.isEmpty()) {
            throw new BusinessException("Link inválido ou vencido. Peça um novo em \"Esqueci minha senha\".");
        }
        Long[] row = rows.get(0);
        AppUser user = users.findById(row[1]).orElseThrow(() -> new BusinessException("Link inválido ou vencido."));
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        jdbc.update("update password_reset set used_at = ? where id = ?", LocalDateTime.now(clock), row[0]);
        jdbc.update("delete from password_reset where user_id = ? and used_at is null", user.getId());
    }

    private static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
