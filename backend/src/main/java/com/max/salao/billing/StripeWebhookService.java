package com.max.salao.billing;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.referral.ReferralService;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import com.max.salao.shared.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Eventos do Stripe (webhook). Cada pagamento de mensalidade ({@code invoice.paid}) estende o plano e gera a
 * comissão do representante; estorno ({@code charge.refunded}) ou contestação ({@code charge.dispute.created})
 * tira o acesso daquele período e a comissão. Tudo idempotente: o Stripe pode reenviar o mesmo evento.
 */
@Service
public class StripeWebhookService {

    private static final Logger log = LoggerFactory.getLogger(StripeWebhookService.class);
    private static final long TOLERANCE_SECONDS = 300;
    static final String PROVIDER = "STRIPE";

    private final StripeProperties props;
    private final ObjectMapper json;
    private final SalonRepository salons;
    private final ReferralService referrals;
    private final BillingService billing;
    private final Clock clock;

    public StripeWebhookService(StripeProperties props, ObjectMapper json, SalonRepository salons,
                                ReferralService referrals, BillingService billing, Clock clock) {
        this.props = props;
        this.json = json;
        this.salons = salons;
        this.referrals = referrals;
        this.billing = billing;
        this.clock = clock;
    }

    /** Confere a assinatura do cabeçalho {@code Stripe-Signature} (t=...,v1=...) contra o corpo cru. */
    public void verify(String payload, String header) {
        if (props.webhookSecret().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Webhook do Stripe não configurado.");
        }
        String timestamp = null;
        List<String> signatures = new ArrayList<>();
        for (String part : header == null ? new String[0] : header.split(",")) {
            String[] kv = part.trim().split("=", 2);
            if (kv.length == 2 && kv[0].equals("t")) {
                timestamp = kv[1];
            } else if (kv.length == 2 && kv[0].equals("v1")) {
                signatures.add(kv[1]);
            }
        }
        if (timestamp == null || signatures.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Assinatura do webhook ausente.");
        }
        long ts;
        try {
            ts = Long.parseLong(timestamp);
        } catch (NumberFormatException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Assinatura do webhook inválida.");
        }
        if (Math.abs(Instant.now(clock).getEpochSecond() - ts) > TOLERANCE_SECONDS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Assinatura do webhook expirada.");
        }
        String expected = hmac(timestamp + "." + payload);
        boolean ok = signatures.stream().anyMatch(s -> MessageDigest.isEqual(
                s.getBytes(StandardCharsets.UTF_8), expected.getBytes(StandardCharsets.UTF_8)));
        if (!ok) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Assinatura do webhook inválida.");
        }
    }

    /** Também usado nos testes para montar o cabeçalho. */
    public String sign(long timestamp, String payload) {
        return "t=" + timestamp + ",v1=" + hmac(timestamp + "." + payload);
    }

    private String hmac(String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.webhookSecret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            StringBuilder hex = new StringBuilder();
            for (byte b : mac.doFinal(data.getBytes(StandardCharsets.UTF_8))) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    @Transactional
    public void handle(String payload) {
        JsonNode event;
        try {
            event = json.readTree(payload);
        } catch (java.io.IOException e) {
            throw new BusinessException("Evento inválido.");
        }
        JsonNode object = event.path("data").path("object");
        switch (event.path("type").asText()) {
            case "checkout.session.completed" -> checkoutCompleted(object);
            case "invoice.paid" -> invoicePaid(object);
            case "charge.refunded" -> chargeRefunded(object);
            case "charge.dispute.created" -> chargeRefunded(object);
            case "customer.subscription.deleted" -> subscriptionDeleted(object);
            default -> log.debug("Evento do Stripe ignorado: {}", event.path("type").asText());
        }
    }

    private void checkoutCompleted(JsonNode session) {
        if (!"subscription".equals(session.path("mode").asText())) {
            return;
        }
        Optional<Salon> salon = salonById(session.path("client_reference_id").asText(""));
        if (salon.isEmpty()) {
            log.warn("Checkout do Stripe sem salão: {}", session.path("id").asText());
            return;
        }
        link(salon.get(), session.path("customer").asText(null), session.path("subscription").asText(null));
    }

    private void invoicePaid(JsonNode invoice) {
        long amount = invoice.path("amount_paid").asLong(0);
        if (amount <= 0) {
            return; // fatura zerada (teste/cupom 100%): não é pagamento
        }
        String customer = invoice.path("customer").asText(null);
        Optional<Salon> found = salonByInvoice(invoice, customer);
        if (found.isEmpty()) {
            // o checkout.session.completed pode chegar depois: erro faz o Stripe reenviar mais tarde
            throw new IllegalStateException("Fatura " + invoice.path("id").asText() + " de salão ainda desconhecido");
        }
        Salon salon = found.get();
        if (salon.getStripeCustomerId() == null && customer != null) {
            link(salon, customer, invoice.path("subscription").asText(null));
        }
        long periodEnd = invoice.path("lines").path("data").path(0).path("period").path("end").asLong(0);
        LocalDate until = periodEnd > 0 ? Instant.ofEpochSecond(periodEnd).atZone(clock.getZone()).toLocalDate() : null;
        String paymentRef = firstText(invoice.path("payment_intent"), invoice.path("charge"));
        boolean isNew = referrals.recordPayment(salon, PROVIDER, invoice.path("id").asText(), paymentRef, (int) amount, until,
                LocalDateTime.now(clock));
        if (isNew && until != null) {
            billing.extendUntil(salon, until);
        }
    }

    private void chargeRefunded(JsonNode node) {
        boolean dispute = node.path("object").asText().equals("dispute");
        // charge.refunded traz o próprio charge; charge.dispute.created traz o charge dentro do campo "charge"
        String chargeId = dispute ? node.path("charge").asText(null) : node.path("id").asText(null);
        if (!dispute) {
            long amount = node.path("amount").asLong(0);
            if (amount <= 0 || node.path("amount_refunded").asLong(0) < amount) {
                log.info("Reembolso parcial do Stripe ignorado: {}", chargeId);
                return; // só estorno total tira o acesso e a comissão
            }
        }
        List<String> refs = new ArrayList<>();
        refs.add(node.path("payment_intent").asText(null));
        refs.add(chargeId);
        refs.add(node.path("invoice").asText(null));
        Optional<ReferralService.Refunded> refunded = referrals.refund(PROVIDER, refs);
        if (refunded.isEmpty() && !dispute) {
            // versões novas da API não ligam o charge à fatura: acha pelo cliente e valor do último pagamento
            salonByCustomer(node.path("customer").asText(null)).flatMap(s ->
                    referrals.refundLatest(PROVIDER, s.getId(), (int) node.path("amount").asLong(0)))
                    .ifPresent(r -> billing.revokeAccess(r.salonId(), r.periodEnd()));
            return;
        }
        refunded.ifPresent(r -> billing.revokeAccess(r.salonId(), r.periodEnd()));
    }

    private void subscriptionDeleted(JsonNode subscription) {
        salonByCustomer(subscription.path("customer").asText(null)).ifPresent(s -> {
            if (subscription.path("id").asText("").equals(s.getStripeSubscriptionId())) {
                s.setStripeSubscriptionId(null);
                salons.save(s);
            }
        });
    }

    private void link(Salon salon, String customer, String subscription) {
        if (customer != null) {
            salon.setStripeCustomerId(customer);
        }
        if (subscription != null) {
            salon.setStripeSubscriptionId(subscription);
        }
        salons.save(salon);
    }

    private Optional<Salon> salonByInvoice(JsonNode invoice, String customer) {
        for (JsonNode meta : new JsonNode[] {
                invoice.path("parent").path("subscription_details").path("metadata"),
                invoice.path("subscription_details").path("metadata"),
                invoice.path("lines").path("data").path(0).path("metadata"),
                invoice.path("metadata")}) {
            Optional<Salon> byMeta = salonById(meta.path("salon_id").asText(""));
            if (byMeta.isPresent()) {
                return byMeta;
            }
        }
        return salonByCustomer(customer);
    }

    private Optional<Salon> salonByCustomer(String customer) {
        return customer == null ? Optional.empty() : salons.findByStripeCustomerId(customer);
    }

    private Optional<Salon> salonById(String id) {
        try {
            return id.isBlank() ? Optional.empty() : salons.findById(Long.valueOf(id));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    private static String firstText(JsonNode... nodes) {
        for (JsonNode n : nodes) {
            if (n.isTextual() && !n.asText().isBlank()) {
                return n.asText();
            }
        }
        return null;
    }

}
