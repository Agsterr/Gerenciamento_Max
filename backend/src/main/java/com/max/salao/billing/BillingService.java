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

    public BillingService(PlayBilling play, SalonService salons, SalonRepository salonRepository,
                          PlatformSettings settings, PlanService plans, Clock clock) {
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
        salon.setPlan(Plan.PAID);
        salon.setPaidUntil(until);
        salon.setPlayPurchaseToken(token);
        salon.setPlayCheckedAt(LocalDateTime.now(clock));
    }
}
