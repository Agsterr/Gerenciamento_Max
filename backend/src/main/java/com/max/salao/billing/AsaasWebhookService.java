package com.max.salao.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.referral.ReferralService;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Avisos do Asaas (webhook). Pagamento confirmado/recebido estende o plano e gera a comissão do representante;
 * estorno ou contestação (chargeback) tira o acesso daquele período e a comissão. Tudo idempotente: o Asaas pode
 * reenviar o mesmo aviso. Nunca devolve erro por um aviso que não dá para ligar a um salão: falhas seguidas fariam o
 * Asaas pausar a fila de avisos.
 */
@Service
public class AsaasWebhookService {

    private static final Logger log = LoggerFactory.getLogger(AsaasWebhookService.class);
    static final String PROVIDER = "ASAAS";

    private final AsaasProperties props;
    private final ObjectMapper json;
    private final SalonRepository salons;
    private final ReferralService referrals;
    private final BillingService billing;
    private final Clock clock;

    public AsaasWebhookService(AsaasProperties props, ObjectMapper json, SalonRepository salons, ReferralService referrals,
                               BillingService billing, Clock clock) {
        this.props = props;
        this.json = json;
        this.salons = salons;
        this.referrals = referrals;
        this.billing = billing;
        this.clock = clock;
    }

    /** O Asaas manda o token combinado no cabeçalho {@code asaas-access-token}. */
    public void verify(String token) {
        if (props.webhookToken().isEmpty() || token == null || !MessageDigest.isEqual(
                token.getBytes(StandardCharsets.UTF_8), props.webhookToken().getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token do webhook inválido.");
        }
    }

    @Transactional
    public void handle(String payload) {
        JsonNode event;
        try {
            event = json.readTree(payload);
        } catch (java.io.IOException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Evento inválido.");
        }
        JsonNode payment = event.path("payment");
        switch (event.path("event").asText()) {
            case "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED" -> paid(payment);
            case "PAYMENT_REFUNDED", "PAYMENT_CHARGEBACK_REQUESTED" -> reversed(payment);
            default -> log.debug("Evento do Asaas ignorado: {}", event.path("event").asText());
        }
    }

    private void paid(JsonNode payment) {
        String id = payment.path("id").asText("");
        BigDecimal value = payment.path("value").decimalValue();
        if (id.isBlank() || value.signum() <= 0) {
            return;
        }
        Optional<Salon> found = salonOf(payment);
        if (found.isEmpty()) {
            log.error("Pagamento do Asaas {} sem salão correspondente (assinatura {}, link {}, referência {})", id,
                    payment.path("subscription").asText(), payment.path("paymentLink").asText(),
                    payment.path("externalReference").asText());
            return;
        }
        Salon salon = found.get();
        link(salon, payment);
        LocalDate due = date(payment.path("dueDate").asText(null));
        LocalDate paidOn = firstDate(payment.path("paymentDate"), payment.path("confirmedDate"), payment.path("clientPaymentDate"));
        LocalDate today = LocalDate.now(clock);
        // o mês pago vai do vencimento (ou do dia do pagamento, se atrasou) por um mês
        LocalDate start = due == null ? (paidOn == null ? today : paidOn)
                : paidOn != null && paidOn.isAfter(due) ? paidOn : due;
        LocalDate until = start.plusMonths(1);
        boolean isNew = referrals.recordPayment(salon, PROVIDER, id, id, value.movePointRight(2).setScale(0, RoundingMode.HALF_UP).intValue(),
                until, LocalDateTime.now(clock));
        if (isNew) {
            billing.extendUntil(salon, until);
        }
    }

    private void reversed(JsonNode payment) {
        String id = payment.path("id").asText("");
        referrals.refund(PROVIDER, List.of(id)).ifPresent(r -> billing.revokeAccess(r.salonId(), r.periodEnd()));
    }

    /** Assinatura, link de pagamento, referência ou cliente: o que ligar primeiro ao salão. */
    private Optional<Salon> salonOf(JsonNode payment) {
        String subscription = payment.path("subscription").asText("");
        if (!subscription.isBlank()) {
            Optional<Salon> s = salons.findByAsaasSubscriptionId(subscription);
            if (s.isPresent()) {
                return s;
            }
        }
        String link = payment.path("paymentLink").asText("");
        if (!link.isBlank()) {
            Optional<Salon> s = salons.findByAsaasLinkId(link);
            if (s.isPresent()) {
                return s;
            }
        }
        String customer = payment.path("customer").asText("");
        if (!customer.isBlank()) {
            Optional<Salon> s = salons.findByAsaasCustomerId(customer);
            if (s.isPresent()) {
                return s;
            }
        }
        try {
            String ref = payment.path("externalReference").asText("");
            return ref.isBlank() ? Optional.empty() : salons.findById(Long.valueOf(ref));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    /** Guarda assinatura e cliente do Asaas no salão para os próximos avisos acharem direto. */
    private void link(Salon salon, JsonNode payment) {
        String subscription = payment.path("subscription").asText("");
        String customer = payment.path("customer").asText("");
        boolean changed = false;
        if (!subscription.isBlank() && !subscription.equals(salon.getAsaasSubscriptionId())) {
            salon.setAsaasSubscriptionId(subscription);
            changed = true;
        }
        if (!customer.isBlank() && !customer.equals(salon.getAsaasCustomerId())) {
            salon.setAsaasCustomerId(customer);
            changed = true;
        }
        if (changed) {
            salons.save(salon);
        }
    }

    private static LocalDate firstDate(JsonNode... nodes) {
        for (JsonNode n : nodes) {
            LocalDate d = date(n.asText(null));
            if (d != null) {
                return d;
            }
        }
        return null;
    }

    private static LocalDate date(String iso) {
        try {
            return iso == null || iso.isBlank() ? null : LocalDate.parse(iso.substring(0, 10));
        } catch (RuntimeException e) {
            return null;
        }
    }
}
