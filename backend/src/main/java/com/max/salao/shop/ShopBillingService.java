package com.max.salao.shop;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

import com.fasterxml.jackson.databind.JsonNode;
import com.max.salao.billing.AsaasProperties;
import com.max.salao.billing.WebBilling;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Assinatura mensal da loja do representante, cobrada pelo Asaas (Pix, boleto ou cartão), com teste grátis a partir do
 * primeiro uso. Sem assinatura (teste vencido e sem pagamento) ele ainda vê pedidos e comissões antigos, mas não cadastra
 * produtos nem recebe pedidos novos.
 */
@Service
public class ShopBillingService {

    private static final Logger log = LoggerFactory.getLogger(ShopBillingService.class);
    /** Folga de um dia depois do fim do período pago, como no plano do salão. */
    static final int GRACE_DAYS = 1;

    public record Plan(String status, LocalDateTime trialEndsAt, LocalDate paidUntil, Long daysLeft, int priceCents,
                       boolean billingAvailable, boolean hasSubscription) {
    }

    private final JdbcTemplate jdbc;
    private final ShopProperties props;
    private final AsaasProperties asaas;
    private final WebBilling web;
    private final Clock clock;

    public ShopBillingService(JdbcTemplate jdbc, ShopProperties props, AsaasProperties asaas, WebBilling web, Clock clock) {
        this.jdbc = jdbc;
        this.props = props;
        this.asaas = asaas;
        this.web = web;
        this.clock = clock;
    }

    /** Situação da assinatura; o teste começa na primeira vez que o representante abre a loja. */
    @Transactional
    public Plan plan(long repId) {
        Timestamp trial = jdbc.queryForObject("select shop_trial_ends from representative where id = ?", Timestamp.class, repId);
        if (trial == null) {
            trial = Timestamp.valueOf(LocalDateTime.now(clock).plusDays(props.trialDays()));
            jdbc.update("update representative set shop_trial_ends = ? where id = ? and shop_trial_ends is null", trial, repId);
        }
        return view(repId, trial.toLocalDateTime());
    }

    private Plan view(long repId, LocalDateTime trialEnds) {
        Date paid = jdbc.queryForObject("select shop_paid_until from representative where id = ?", Date.class, repId);
        String sub = jdbc.queryForObject("select asaas_subscription_id from representative where id = ?", String.class, repId);
        LocalDateTime now = LocalDateTime.now(clock);
        LocalDate paidUntil = paid == null ? null : paid.toLocalDate();
        String status;
        Long days;
        if (paidUntil != null && !LocalDate.now(clock).isAfter(paidUntil)) {
            status = "ACTIVE";
            days = ChronoUnit.DAYS.between(LocalDate.now(clock), paidUntil);
        } else if (trialEnds != null && now.isBefore(trialEnds)) {
            status = "TRIAL";
            days = Math.max(0, (long) Math.ceil(java.time.Duration.between(now, trialEnds).toHours() / 24.0));
        } else {
            status = "EXPIRED";
            days = 0L;
        }
        return new Plan(status, trialEnds, paidUntil, days, props.priceCents(), asaas.configured(), sub != null);
    }

    /** A loja está liberada (teste ou assinatura em dia)? Não inicia o teste. */
    @Transactional(readOnly = true)
    public boolean active(long repId) {
        Timestamp trial = jdbc.queryForObject("select shop_trial_ends from representative where id = ?", Timestamp.class, repId);
        String status = view(repId, trial == null ? null : trial.toLocalDateTime()).status();
        return !status.equals("EXPIRED");
    }

    /** Para as ações de vender: se a assinatura venceu, avisa o representante. */
    @Transactional
    public void requireActive(long repId) {
        if ("EXPIRED".equals(plan(repId).status())) {
            throw new BusinessException("Sua assinatura da loja venceu. Assine para continuar cadastrando produtos e recebendo pedidos.");
        }
    }

    /** Abre a página de pagamento (Pix, boleto ou cartão) da mensalidade da loja. */
    @Transactional
    public String checkout(long repId, String cpfCnpj) {
        if (!asaas.configured()) {
            throw new BusinessException("O pagamento pelo site ainda não está disponível.");
        }
        Plan plan = plan(repId);
        String sub = jdbc.queryForObject("select asaas_subscription_id from representative where id = ?", String.class, repId);
        if (sub != null && "ACTIVE".equals(plan.status())) {
            throw new BusinessException("Sua assinatura da loja já está ativa. O próximo pagamento chega por e-mail no vencimento.");
        }
        if (sub != null) {
            Optional<String> open = web.openPaymentUrl(sub);
            if (open.isPresent()) {
                return open.get();
            }
            try {
                web.cancelSubscription(sub);
            } catch (RuntimeException e) {
                log.warn("Não foi possível encerrar a assinatura anterior da loja do representante {}: {}", repId, e.getMessage());
            }
            jdbc.update("update representative set asaas_subscription_id = null where id = ?", repId);
        }
        var user = jdbc.queryForMap("select u.name, u.email from representative r join app_user u on u.id = r.user_id where r.id = ?", repId);
        String customerId = jdbc.queryForObject("select asaas_customer_id from representative where id = ?", String.class, repId);
        WebBilling.Subscribed created = web.subscribeCustom(customerId, (String) user.get("name"), (String) user.get("email"),
                cpfCnpj == null ? null : cpfCnpj.replaceAll("\\D", ""), props.priceCents(), "Loja do representante Salão Max", "rep:" + repId);
        jdbc.update("update representative set asaas_customer_id = ?, asaas_subscription_id = ? where id = ?", created.customerId(), created.subscriptionId(), repId);
        return created.url();
    }

    /** Cancela a cobrança mensal; o que já foi pago continua valendo até o fim do período. */
    @Transactional
    public Plan cancel(long repId) {
        String sub = jdbc.queryForObject("select asaas_subscription_id from representative where id = ?", String.class, repId);
        if (sub == null) {
            throw new BusinessException("Você não tem assinatura da loja para cancelar.");
        }
        web.cancelSubscription(sub);
        jdbc.update("update representative set asaas_subscription_id = null where id = ?", repId);
        return plan(repId);
    }

    // ---- avisos do Asaas ----

    /** O pagamento (aviso do Asaas) é de um representante? Se for, registra e devolve {@code true}. */
    @Transactional
    public boolean handlePaid(JsonNode payment, int amountCents, LocalDate periodEnd, LocalDateTime paidAt) {
        Optional<Long> rep = repOf(payment);
        if (rep.isEmpty()) {
            return false;
        }
        String id = payment.path("id").asText("");
        int inserted = jdbc.update("insert into shop_subscription_payment (representative_id, external_id, amount_cents, period_end, paid_at) "
                + "values (?,?,?,?,?) on conflict (external_id) do nothing", rep.get(), id, amountCents, Date.valueOf(periodEnd), Timestamp.valueOf(paidAt));
        if (inserted > 0) {
            LocalDate until = periodEnd.plusDays(GRACE_DAYS);
            jdbc.update("update representative set shop_paid_until = ? where id = ? and (shop_paid_until is null or shop_paid_until < ?)", Date.valueOf(until), rep.get(), Date.valueOf(until));
            String sub = payment.path("subscription").asText("");
            String customer = payment.path("customer").asText("");
            if (!sub.isBlank()) {
                jdbc.update("update representative set asaas_subscription_id = ? where id = ? and asaas_subscription_id is null", sub, rep.get());
            }
            if (!customer.isBlank()) {
                jdbc.update("update representative set asaas_customer_id = ? where id = ? and asaas_customer_id is null", customer, rep.get());
            }
        }
        return true;
    }

    /** Estorno: se era o período em vigor, o acesso pago acaba hoje. Devolve {@code true} se era de representante. */
    @Transactional
    public boolean handleReversed(String externalId) {
        List<Object[]> found = jdbc.query("select id, representative_id, period_end, status from shop_subscription_payment where external_id = ?",
                (rs, i) -> new Object[] {rs.getLong(1), rs.getLong(2), rs.getDate(3), rs.getString(4)}, externalId);
        if (found.isEmpty()) {
            return false;
        }
        Object[] f = found.get(0);
        if (!"REFUNDED".equals(f[3])) {
            jdbc.update("update shop_subscription_payment set status = 'REFUNDED' where id = ?", f[0]);
            LocalDate until = ((Date) f[2]).toLocalDate().plusDays(GRACE_DAYS);
            jdbc.update("update representative set shop_paid_until = ? where id = ? and shop_paid_until = ?",
                    Date.valueOf(LocalDate.now(clock).minusDays(1)), f[1], Date.valueOf(until));
        }
        return true;
    }

    private Optional<Long> repOf(JsonNode payment) {
        for (String[] key : new String[][] {{"subscription", "asaas_subscription_id"}, {"customer", "asaas_customer_id"}}) {
            String v = payment.path(key[0]).asText("");
            if (!v.isBlank()) {
                List<Long> l = jdbc.queryForList("select id from representative where " + key[1] + " = ?", Long.class, v);
                if (!l.isEmpty()) {
                    return Optional.of(l.get(0));
                }
            }
        }
        String ref = payment.path("externalReference").asText("");
        if (ref.startsWith("rep:")) {
            try {
                long id = Long.parseLong(ref.substring(4));
                List<Long> l = jdbc.queryForList("select id from representative where id = ?", Long.class, id);
                return l.isEmpty() ? Optional.empty() : Optional.of(id);
            } catch (NumberFormatException e) {
                return Optional.empty();
            }
        }
        return Optional.empty();
    }

    static int cents(BigDecimal value) {
        return value.movePointRight(2).setScale(0, RoundingMode.HALF_UP).intValue();
    }
}
