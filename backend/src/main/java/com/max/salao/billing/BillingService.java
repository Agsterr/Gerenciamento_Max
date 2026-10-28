package com.max.salao.billing;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.max.salao.plan.Plan;
import com.max.salao.plan.PlanService;
import com.max.salao.plan.PlanService.PlanInfo;
import com.max.salao.plan.PlatformSettings;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.referral.ReferralProperties;
import com.max.salao.referral.ReferralService;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Assinatura do app de gestão pela Google Play. O app manda o token da compra; a API confere com a Google,
 * confirma a compra (acknowledge) e passa o salão para o plano pago até o fim do período pago. Uma rotina
 * diária reconfere quem está perto de vencer (renovação, cancelamento, cobrança que falhou).
 */
@Service
public class BillingService {

    private static final Logger log = LoggerFactory.getLogger(BillingService.class);

    /** Folga depois do fim do período pago, para a renovação da Google não deixar o salão sem plano por horas. */
    static final int GRACE_DAYS = 1;

    private final PlayBilling play;
    private final SalonService salons;
    private final SalonRepository salonRepository;
    private final PlatformSettings settings;
    private final PlanService plans;
    private final Clock clock;
    private final ReferralService referrals;
    private final ReferralProperties referralProps;
    private final WebBilling web;
    private final AsaasProperties asaas;
    private final AppUserRepository users;

    public BillingService(PlayBilling play, SalonService salons, SalonRepository salonRepository,
                          PlatformSettings settings, PlanService plans, Clock clock, ReferralService referrals,
                          ReferralProperties referralProps, WebBilling web, AsaasProperties asaas, AppUserRepository users) {
        this.referrals = referrals;
        this.referralProps = referralProps;
        this.web = web;
        this.asaas = asaas;
        this.users = users;
        this.play = play;
        this.salons = salons;
        this.salonRepository = salonRepository;
        this.settings = settings;
        this.plans = plans;
        this.clock = clock;
    }

    /** Compra feita no app: confere com a Google e ativa o plano. */
    @Transactional
    public PlanInfo verify(String productId, String purchaseToken) {
        Salon salon = salons.current();
        PlatformSettings.Values cfg = settings.get();
        if (!cfg.billingEnabled() && !salon.isBillingPreview()) {
            throw new BusinessException("A assinatura pela loja ainda não está disponível.");
        }
        if (!cfg.playProductId().equals(productId)) {
            throw new BusinessException("Produto de assinatura desconhecido.");
        }
        salonRepository.findByPlayPurchaseToken(purchaseToken)
                .filter(other -> !other.getId().equals(salon.getId()))
                .ifPresent(other -> {
                    throw new BusinessException("Esta assinatura já está em uso por outro salão.");
                });

        PlaySubscription sub = play.lookup(purchaseToken);
        if (!sub.entitled(Instant.now())) {
            throw new BusinessException("A assinatura não está ativa na Google Play (status: " + sub.state() + ").");
        }
        if (!sub.acknowledged()) {
            play.acknowledge(productId, purchaseToken);
        }
        apply(salon, purchaseToken, sub);
        try {
            salonRepository.saveAndFlush(salon);
        } catch (DataIntegrityViolationException e) {
            throw new BusinessException("Esta assinatura já está em uso por outro salão.");
        }
        return plans.info();
    }

    /** Reconfere a assinatura do salão atual (botão "restaurar" / abertura do app). */
    @Transactional
    public PlanInfo sync() {
        Salon salon = salons.current();
        if (salon.getPlayPurchaseToken() != null) {
            refresh(salon);
        }
        return plans.info();
    }

    /** Rotina diária: reconfere quem vence nos próximos dias (ou já venceu). Retorna quantos salões mudaram. */
    @Transactional
    public int syncDue() {
        List<Salon> due = salonRepository.playSubscribersDueUntil(LocalDate.now(clock).plusDays(2));
        int changed = 0;
        for (Salon salon : due) {
            try {
                LocalDate before = salon.getPaidUntil();
                refresh(salon);
                if (!java.util.Objects.equals(before, salon.getPaidUntil())) {
                    changed++;
                }
            } catch (RuntimeException e) {
                log.warn("Não foi possível reconferir a assinatura do salão {}: {}", salon.getId(), e.getMessage());
            }
        }
        if (!due.isEmpty()) {
            log.info("Assinaturas da Play reconferidas: {} (mudaram: {})", due.size(), changed);
        }
        return changed;
    }

    private void refresh(Salon salon) {
        PlaySubscription sub = play.lookup(salon.getPlayPurchaseToken());
        if (sub.expiry() != null) {
            apply(salon, salon.getPlayPurchaseToken(), sub);
        }
        if (sub.entitled(Instant.now()) && !sub.acknowledged()) {
            play.acknowledge(sub.productId(), salon.getPlayPurchaseToken());
        }
    }

    /** O plano vale até o fim do período pago; se a Google não renovar, o salão volta a só consulta sozinho. */
    private void apply(Salon salon, String token, PlaySubscription sub) {
        LocalDate until = sub.expiry().atZone(clock.getZone()).toLocalDate().plusDays(GRACE_DAYS);
        // cada renovação paga (pedido novo) entra no registro de pagamentos e gera a comissão de quem indicou
        boolean advanced = salon.getPaidUntil() == null || until.isAfter(salon.getPaidUntil());
        if (advanced && sub.entitled(Instant.now()) && sub.orderId() != null && !sub.orderId().isBlank()) {
            referrals.recordPayment(salon, "PLAY", sub.orderId(), sub.orderId(), referralProps.playPriceCents(),
                    until.minusDays(GRACE_DAYS), LocalDateTime.now(clock));
        }
        salon.setPlan(Plan.PAID);
        salon.setPaidUntil(until);
        salon.setPlayPurchaseToken(token);
        salon.setPlayCheckedAt(LocalDateTime.now(clock));
    }

    // ---- Pagamento pelo site (Asaas) ----

    /** Abre a página de pagamento do site (Pix, boleto ou cartão) para o salão atual. */
    @Transactional
    public String webCheckout() {
        Salon salon = salons.current();
        if (com.max.salao.shared.AppChannel.isStoreApp()) {
            throw new BusinessException("Na versão da loja a assinatura é feita pela Google Play.");
        }
        if (!asaas.configured()) {
            throw new BusinessException("O pagamento pelo site ainda não está disponível.");
        }
        boolean active = plans.status(salon) == com.max.salao.plan.PlanStatus.ACTIVE;
        if (salon.getPlayPurchaseToken() != null && active) {
            throw new BusinessException("Seu plano é assinado pela Google Play. Gerencie por lá.");
        }
        if (salon.getAsaasSubscriptionId() != null && active) {
            throw new BusinessException("Seu plano já está ativo. O próximo pagamento chega por e-mail no vencimento.");
        }
        // link já criado e ainda sem pagamento: reaproveita (um pagamento no link antigo continua ligado ao salão)
        if (salon.getAsaasLinkId() != null && salon.getAsaasSubscriptionId() == null) {
            var existing = web.findLink(salon.getAsaasLinkId());
            if (existing.isPresent()) {
                return existing.get().url();
            }
        }
        // assinatura anterior que ficou sem pagar: encerra para não cobrar duas vezes
        if (salon.getAsaasSubscriptionId() != null) {
            try {
                web.cancelSubscription(salon.getAsaasSubscriptionId());
            } catch (RuntimeException e) {
                log.warn("Não foi possível encerrar a assinatura anterior do salão {}: {}", salon.getId(), e.getMessage());
            }
            salon.setAsaasSubscriptionId(null);
        }
        WebBilling.Link link = web.createLink(salon);
        salon.setAsaasLinkId(link.id());
        salonRepository.save(salon);
        return link.url();
    }

    /** Cancela a assinatura do site: não cobra mais; o plano vale até o fim do período já pago. */
    @Transactional
    public PlanInfo webCancel() {
        Salon salon = salons.current();
        if (salon.getAsaasSubscriptionId() == null) {
            throw new BusinessException("Este salão não tem assinatura pelo site para cancelar.");
        }
        web.cancelSubscription(salon.getAsaasSubscriptionId());
        salon.setAsaasSubscriptionId(null);
        salonRepository.save(salon);
        return plans.info();
    }

    /** Pagamento confirmado: plano pago até o fim do período (mais a folga), sem encurtar o que já valia. */
    @Transactional
    void extendUntil(Salon salon, LocalDate periodEnd) {
        LocalDate until = periodEnd.plusDays(GRACE_DAYS);
        salon.setPlan(Plan.PAID);
        if (salon.getPaidUntil() == null || until.isAfter(salon.getPaidUntil())) {
            salon.setPaidUntil(until);
        }
        salonRepository.save(salon);
    }

    /** Pagamento estornado: se era o período em vigor, o acesso pago acaba hoje. */
    @Transactional
    void revokeAccess(Long salonId, LocalDate periodEnd) {
        if (salonId == null || periodEnd == null) {
            return;
        }
        salonRepository.findById(salonId).ifPresent(salon -> {
            if (periodEnd.plusDays(GRACE_DAYS).equals(salon.getPaidUntil())) {
                salon.setPaidUntil(LocalDate.now(clock).minusDays(1));
                salonRepository.save(salon);
            }
        });
    }

    /** Rotina diária: pedidos da Play estornados nos últimos 30 dias tiram a comissão e o acesso. */
    @Transactional
    public int reverseVoidedPlayOrders() {
        int reversed = 0;
        for (String orderId : play.voidedOrderIds(Instant.now().minus(java.time.Duration.ofDays(30)))) {
            var refunded = referrals.refund("PLAY", List.of(orderId));
            if (refunded.isPresent()) {
                revokeAccess(refunded.get().salonId(), refunded.get().periodEnd());
                reversed++;
            }
        }
        return reversed;
    }
}
