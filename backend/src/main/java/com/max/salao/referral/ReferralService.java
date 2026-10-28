package com.max.salao.referral;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.text.Normalizer;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.max.salao.auth.AppUser;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.auth.AuthDtos.TokenResponse;
import com.max.salao.auth.AuthDtos.UserResponse;
import com.max.salao.auth.Role;
import com.max.salao.plan.PlanService;
import com.max.salao.plan.PlanStatus;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import com.max.salao.security.JwtService;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Programa de representantes. Cada representante tem um código (link {@code /r/CODIGO}); o salão que se cadastra
 * por ele fica ligado a ele para sempre. Toda mensalidade paga desse salão (site ou Play) gera uma comissão fixa;
 * se o pagamento for estornado ou contestado, a comissão é perdida (REVERSED). Cancelar a assinatura apenas para
 * de gerar comissões novas. Valores em centavos.
 */
@Service
public class ReferralService {

    private static final Logger log = LoggerFactory.getLogger(ReferralService.class);
    /** Sem 0/O/1/I para o código não gerar dúvida quando falado ou digitado. */
    private static final String ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    private final SecureRandom random = new SecureRandom();

    /** Resumo do que o representante tem a receber. */
    public record Totals(long releasingCents, long availableCents, long paidCents, long reversedCents, long paidMonths) {
    }

    public record ReferredSalon(Long id, String name, LocalDateTime createdAt, String status, long paidMonths, long earnedCents) {
    }

    public record CommissionLine(Long id, String salonName, LocalDateTime createdAt, long amountCents, String status,
                                 LocalDateTime availableAt) {
    }

    public record Dashboard(String name, String email, String code, String link, String pixKey, int commissionCents,
                            int holdDays, Totals totals, List<ReferredSalon> salons, List<CommissionLine> commissions) {
    }

    public record RepresentativeSummary(Long id, Long userId, String name, String email, String code, String pixKey,
                                        boolean blocked, long salons, long payingSalons, Totals totals) {
    }

    private final JdbcTemplate jdbc;
    private final AppUserRepository users;
    private final SalonRepository salons;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwt;
    private final PlanService plans;
    private final ReferralProperties props;
    private final Clock clock;

    public ReferralService(JdbcTemplate jdbc, AppUserRepository users, SalonRepository salons, PasswordEncoder passwordEncoder,
                           JwtService jwt, PlanService plans, ReferralProperties props, Clock clock) {
        this.jdbc = jdbc;
        this.users = users;
        this.salons = salons;
        this.passwordEncoder = passwordEncoder;
        this.jwt = jwt;
        this.plans = plans;
        this.props = props;
        this.clock = clock;
    }

    // ---- Cadastro e código ----

    @Transactional
    public TokenResponse register(String name, String email, String password, String pixKey) {
        if (users.existsByEmailIgnoreCase(email)) {
            throw new BusinessException("E-mail já cadastrado");
        }
        AppUser user = new AppUser();
        user.setName(name.trim());
        user.setEmail(email.trim().toLowerCase());
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(Role.REPRESENTATIVE);
        user = users.save(user);
        jdbc.update("INSERT INTO representative (user_id, code, pix_key) VALUES (?, ?, ?)",
                user.getId(), newCode(name), blankToNull(pixKey));
        return new TokenResponse(jwt.issue(user),
                new UserResponse(user.getId(), user.getName(), user.getEmail(), user.getRole(), null, null));
    }

    private String newCode(String name) {
        String letters = Normalizer.normalize(name, Normalizer.Form.NFD).replaceAll("[^A-Za-z]", "").toUpperCase();
        String prefix = letters.length() >= 3 ? letters.substring(0, Math.min(4, letters.length())) : "REP";
        for (int i = 0; i < 20; i++) {
            StringBuilder code = new StringBuilder(prefix);
            for (int j = 0; j < 4; j++) {
                code.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
            }
            Integer taken = jdbc.queryForObject("SELECT count(*) FROM representative WHERE code = ?", Integer.class, code.toString());
            if (taken != null && taken == 0) {
                return code.toString();
            }
        }
        throw new IllegalStateException("Não foi possível gerar um código de representante");
    }

    /** Código digitado/vindo do link -> representante ativo (maiúsculas/minúsculas não importam). */
    @Transactional(readOnly = true)
    public Optional<Long> findIdByCode(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }
        return jdbc.query("""
                SELECT r.id FROM representative r JOIN app_user u ON u.id = r.user_id
                WHERE r.code = ? AND u.active = TRUE AND u.blocked = FALSE""", (rs, i) -> rs.getLong(1),
                code.trim().toUpperCase()).stream().findFirst();
    }

    /** Primeiro nome de quem indicou (página de cadastro: "Indicado por Maria"); vazio se o código não existe. */
    @Transactional(readOnly = true)
    public Optional<String> publicName(String code) {
        return findIdByCode(code).flatMap(id -> jdbc.query(
                "SELECT u.name FROM representative r JOIN app_user u ON u.id = r.user_id WHERE r.id = ?",
                (rs, i) -> rs.getString(1).trim().split("\\s+")[0], id).stream().findFirst());
    }

    @Transactional
    public void updatePix(Long userId, String pixKey) {
        jdbc.update("UPDATE representative SET pix_key = ? WHERE user_id = ?", blankToNull(pixKey), userId);
    }

    // ---- Pagamentos e comissões ----

    /**
     * Registra uma mensalidade paga. Idempotente por (provedor, código externo): repetir o mesmo pagamento
     * (reenvio do webhook, reconferência da Play) não duplica nada. Se o salão foi indicado, gera a comissão.
     *
     * @return {@code true} se o pagamento era novo
     */
    @Transactional
    public boolean recordPayment(Salon salon, String provider, String externalId, String paymentRef, int amountCents,
                                 LocalDate periodEnd, LocalDateTime paidAt) {
        Long paymentId = jdbc.query("""
                INSERT INTO subscription_payment (salon_id, salon_name, provider, external_id, payment_ref, amount_cents, period_end, paid_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (provider, external_id) DO NOTHING
                RETURNING id""", (rs, i) -> rs.getLong(1),
                salon.getId(), salon.getName(), provider, externalId, paymentRef, amountCents,
                periodEnd == null ? null : java.sql.Date.valueOf(periodEnd), Timestamp.valueOf(paidAt))
                .stream().findFirst().orElse(null);
        if (paymentId == null) {
            return false;
        }
        if (salon.getReferrerId() != null) {
            jdbc.update("""
                    INSERT INTO commission (representative_id, salon_id, salon_name, payment_id, amount_cents, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)""", salon.getReferrerId(), salon.getId(), salon.getName(), paymentId,
                    props.commissionCents(), Timestamp.valueOf(paidAt));
        }
        return true;
    }

    /** Pagamento estornado ou contestado: a comissão dele é perdida. */
    public record Refunded(Long salonId, LocalDate periodEnd) {
    }

    /**
     * Marca como estornado o pagamento que bate com algum dos códigos (código externo ou referência do pagamento).
     * Repetir não faz nada.
     */
    @Transactional
    public Optional<Refunded> refund(String provider, List<String> refs) {
        List<String> keys = refs.stream().filter(r -> r != null && !r.isBlank()).toList();
        if (keys.isEmpty()) {
            return Optional.empty();
        }
        String marks = String.join(",", keys.stream().map(k -> "?").toList());
        List<Object> args = new java.util.ArrayList<>();
        args.add(provider);
        args.addAll(keys);
        args.addAll(keys);
        List<Object[]> found = jdbc.query("""
                SELECT id, salon_id, period_end, status FROM subscription_payment
                WHERE provider = ? AND (external_id IN (%s) OR payment_ref IN (%s))""".formatted(marks, marks),
                (rs, i) -> new Object[] {rs.getLong(1), (Long) rs.getObject(2), rs.getDate(3), rs.getString(4)}, args.toArray());
        if (found.isEmpty()) {
            log.warn("Estorno de {} sem pagamento registrado: {}", provider, keys);
            return Optional.empty();
        }
        Object[] row = found.get(0);
        if (!"PAID".equals(row[3])) {
            return Optional.empty();
        }
        Timestamp now = Timestamp.valueOf(LocalDateTime.now(clock));
        jdbc.update("UPDATE subscription_payment SET status = 'REFUNDED', refunded_at = ? WHERE id = ?", now, row[0]);
        jdbc.update("UPDATE commission SET status = 'REVERSED', reversed_at = ? WHERE payment_id = ?", now, row[0]);
        java.sql.Date end = (java.sql.Date) row[2];
        return Optional.of(new Refunded((Long) row[1], end == null ? null : end.toLocalDate()));
    }

    /** Estorno sem referência do pagamento: pega o último pagamento pago do salão com o mesmo valor. */
    @Transactional
    public Optional<Refunded> refundLatest(String provider, Long salonId, int amountCents) {
        return jdbc.query("SELECT external_id FROM subscription_payment WHERE provider = ? AND salon_id = ? AND status = 'PAID' "
                        + "AND amount_cents = ? ORDER BY paid_at DESC, id DESC LIMIT 1", (rs, i) -> rs.getString(1),
                provider, salonId, amountCents).stream().findFirst().flatMap(id -> refund(provider, List.of(id)));
    }

    // ---- Painel do representante ----

    @Transactional(readOnly = true)
    public Dashboard dashboard(Long userId) {
        AppUser user = users.findById(userId).orElseThrow(() -> new NotFoundException("Usuário não encontrado"));
        Map<String, Object> rep = jdbc.queryForMap("SELECT id, code, pix_key FROM representative WHERE user_id = ?", userId);
        Long repId = (Long) rep.get("id");
        String code = (String) rep.get("code");

        Map<Long, long[]> perSalon = new HashMap<>();
        jdbc.query("""
                SELECT salon_id, count(*) FILTER (WHERE status <> 'REVERSED'),
                       coalesce(sum(amount_cents) FILTER (WHERE status <> 'REVERSED'), 0)
                FROM commission WHERE representative_id = ? AND salon_id IS NOT NULL GROUP BY salon_id""",
                rs -> {
                    perSalon.put(rs.getLong(1), new long[] {rs.getLong(2), rs.getLong(3)});
                }, repId);
        List<ReferredSalon> referred = salons.findByReferrerIdOrderByCreatedAtDesc(repId).stream().map(s -> {
            long[] c = perSalon.getOrDefault(s.getId(), new long[] {0, 0});
            return new ReferredSalon(s.getId(), s.getName(), s.getCreatedAt(), statusOf(s), c[0], c[1]);
        }).toList();

        int hold = props.holdDays();
        List<CommissionLine> lines = jdbc.query("""
                SELECT id, salon_name, created_at, amount_cents, status FROM commission
                WHERE representative_id = ? ORDER BY created_at DESC, id DESC LIMIT 100""", (rs, i) -> {
            LocalDateTime created = rs.getTimestamp(3).toLocalDateTime();
            return new CommissionLine(rs.getLong(1), rs.getString(2), created, rs.getLong(4), rs.getString(5), created.plusDays(hold));
        }, repId);

        return new Dashboard(user.getName(), user.getEmail(), code, link(code), (String) rep.get("pix_key"),
                props.commissionCents(), hold, totals(repId), referred, lines);
    }

    /** "PAGANDO" só com plano pago em dia; "TESTE" no teste grátis; "VENCIDO" sem plano ativo. */
    private String statusOf(Salon s) {
        PlanStatus status = plans.status(s);
        return switch (status) {
            case ACTIVE -> "PAGANDO";
            case TRIAL -> "TESTE";
            case EXPIRED -> "VENCIDO";
        };
    }

    private Totals totals(Long repId) {
        LocalDateTime limit = LocalDateTime.now(clock).minusDays(props.holdDays());
        return jdbc.query("""
                SELECT coalesce(sum(amount_cents) FILTER (WHERE status = 'PENDING' AND created_at > ?), 0),
                       coalesce(sum(amount_cents) FILTER (WHERE status = 'PENDING' AND created_at <= ?), 0),
                       coalesce(sum(amount_cents) FILTER (WHERE status = 'PAID'), 0),
                       coalesce(sum(amount_cents) FILTER (WHERE status = 'REVERSED'), 0),
                       count(*) FILTER (WHERE status <> 'REVERSED')
                FROM commission WHERE representative_id = ?""",
                rs -> {
                    rs.next();
                    return new Totals(rs.getLong(1), rs.getLong(2), rs.getLong(3), rs.getLong(4), rs.getLong(5));
                }, Timestamp.valueOf(limit), Timestamp.valueOf(limit), repId);
    }

    private String link(String code) {
        return props.siteUrl() + "/r/" + code;
    }

    // ---- Administração (plataforma) ----

    @Transactional(readOnly = true)
    public List<RepresentativeSummary> listForAdmin() {
        return jdbc.query("""
                SELECT r.id, r.user_id, u.name, u.email, r.code, r.pix_key, u.blocked
                FROM representative r JOIN app_user u ON u.id = r.user_id ORDER BY u.name""", (rs, i) -> {
            Long repId = rs.getLong(1);
            long salonCount = jdbc.queryForObject("SELECT count(*) FROM salon WHERE referrer_id = ?", Long.class, repId);
            long paying = salons.findByReferrerIdOrderByCreatedAtDesc(repId).stream()
                    .filter(s -> plans.status(s) == PlanStatus.ACTIVE && s.getPlan() == com.max.salao.plan.Plan.PAID).count();
            return new RepresentativeSummary(repId, rs.getLong(2), rs.getString(3), rs.getString(4), rs.getString(5),
                    rs.getString(6), rs.getBoolean(7), salonCount, paying, totals(repId));
        });
    }

    /** Repassa (marca como pagas) as comissões disponíveis do representante. Retorna o valor repassado em centavos. */
    @Transactional
    public long payOut(Long representativeId) {
        LocalDateTime now = LocalDateTime.now(clock);
        Timestamp limit = Timestamp.valueOf(now.minusDays(props.holdDays()));
        Long amount = jdbc.queryForObject("""
                SELECT coalesce(sum(amount_cents), 0) FROM commission
                WHERE representative_id = ? AND status = 'PENDING' AND created_at <= ?""", Long.class, representativeId, limit);
        jdbc.update("""
                UPDATE commission SET status = 'PAID', paid_at = ?
                WHERE representative_id = ? AND status = 'PENDING' AND created_at <= ?""",
                Timestamp.valueOf(now), representativeId, limit);
        return amount == null ? 0 : amount;
    }

    private static String blankToNull(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }
}
