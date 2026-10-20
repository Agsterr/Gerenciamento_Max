package com.max.salao.plan;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;

import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.customer.CustomerRepository;
import com.max.salao.portfolio.PortfolioPhotoRepository;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.AppChannel;
import com.max.salao.shared.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Regras do teste grátis: prazo, limites de cadastro e salão vencido só para consulta. */
@Service
public class PlanService {

    public enum Resource {
        PROFESSIONALS("profissionais"), SERVICES("serviços"), CUSTOMERS("clientes");

        final String label;

        Resource(String label) {
            this.label = label;
        }
    }

    public record Usage(long used, int max) {
    }

    public record PlanInfo(PlanStatus status, Plan plan, LocalDateTime trialEndsAt, LocalDate paidUntil, Long daysLeft,
                           Usage professionals, Usage services, Usage customers,
                           String contactWhatsapp, String contactEmail, Usage photos) {
    }

    private final SalonService salons;
    private final PlatformSettings settings;
    private final ProfessionalRepository professionals;
    private final ServiceItemRepository services;
    private final CustomerRepository customers;
    private final PortfolioPhotoRepository photos;
    private final Clock clock;

    public PlanService(SalonService salons, PlatformSettings settings, ProfessionalRepository professionals,
                       ServiceItemRepository services, CustomerRepository customers, PortfolioPhotoRepository photos,
                       Clock clock) {
        this.photos = photos;
        this.salons = salons;
        this.settings = settings;
        this.professionals = professionals;
        this.services = services;
        this.customers = customers;
        this.clock = clock;
    }

    public PlanStatus status(Salon s) {
        LocalDateTime now = LocalDateTime.now(clock);
        if (s.getPlan() == Plan.PAID) {
            return s.getPaidUntil() == null || !now.toLocalDate().isAfter(s.getPaidUntil()) ? PlanStatus.ACTIVE : PlanStatus.EXPIRED;
        }
        return now.isBefore(s.getTrialEndsAt()) ? PlanStatus.TRIAL : PlanStatus.EXPIRED;
    }

    /** Novo salão: começa em teste pelo prazo configurado. */
    public void startTrial(Salon s) {
        s.setPlan(Plan.TRIAL);
        s.setTrialEndsAt(LocalDateTime.now(clock).plusDays(settings.get().trialDays()));
        s.setPaidUntil(null);
    }

    @Transactional(readOnly = true)
    public PlanInfo info() {
        Salon s = salons.current();
        PlatformSettings.Values cfg = settings.get();
        PlanStatus status = status(s);
        boolean limited = status != PlanStatus.ACTIVE;
        Long daysLeft = switch (status) {
            case TRIAL -> Math.max(0, (long) Math.ceil(Duration.between(LocalDateTime.now(clock), s.getTrialEndsAt()).toHours() / 24.0));
            case ACTIVE -> s.getPaidUntil() == null ? null
                    : java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(clock), s.getPaidUntil());
            case EXPIRED -> 0L;
        };
        return new PlanInfo(status, s.getPlan(), s.getTrialEndsAt(), s.getPaidUntil(), daysLeft,
                new Usage(professionals.count(), limited ? cfg.maxProfessionals() : 0),
                new Usage(services.count(), limited ? cfg.maxServices() : 0),
                new Usage(customers.count(), limited ? cfg.maxCustomers() : 0),
                cfg.contactWhatsapp(), cfg.contactEmail(),
                new Usage(photos.count(), photoLimit(status, cfg)));
    }

    private static int photoLimit(PlanStatus status, PlatformSettings.Values cfg) {
        return status == PlanStatus.ACTIVE ? cfg.maxPhotosPaid() : cfg.maxPhotos();
    }

    /** Fotos do portfólio têm limite no teste e também no plano pago (espaço no R2). */
    @Transactional(readOnly = true)
    public void checkPhotoLimit() {
        PlanStatus status = status(salons.current());
        int max = photoLimit(status, settings.get());
        if (photos.count() >= max) {
            throw new BusinessException(status == PlanStatus.ACTIVE
                    ? "Limite de " + max + " fotos atingido. Apague fotos antigas para enviar novas."
                    : "No teste grátis o limite é de " + max + " fotos"
                      + (AppChannel.isStoreApp() ? "." : ". Para enviar mais, ative o plano com o Salão Max."));
        }
    }

    /** Barra alterações quando o teste ou o plano venceu. */
    @Transactional(readOnly = true)
    public void requireActive(boolean publicBooking) {
        if (status(salons.current()) == PlanStatus.EXPIRED) {
            throw new PlanExpiredException(publicBooking
                    ? "Agendamento online indisponível no momento. Fale direto com o salão."
                    : AppChannel.isStoreApp()
                    ? "Seu período de teste terminou. Você ainda pode consultar tudo, mas não pode cadastrar "
                      + "nem receber agendamentos."
                    : "Seu período de teste terminou. Você ainda pode consultar tudo; para voltar a cadastrar e "
                      + "receber agendamentos, fale com o Salão Max e ative seu plano.");
        }
    }

    /** No teste grátis, limita quantos profissionais, serviços e clientes o salão pode cadastrar. */
    @Transactional(readOnly = true)
    public void checkLimit(Resource resource) {
        if (status(salons.current()) == PlanStatus.ACTIVE) {
            return;
        }
        PlatformSettings.Values cfg = settings.get();
        long used;
        int max;
        switch (resource) {
            case PROFESSIONALS -> { used = professionals.count(); max = cfg.maxProfessionals(); }
            case SERVICES -> { used = services.count(); max = cfg.maxServices(); }
            default -> { used = customers.count(); max = cfg.maxCustomers(); }
        }
        if (used >= max) {
            throw new BusinessException("No teste grátis o limite é de " + max + " " + resource.label
                    + (AppChannel.isStoreApp() ? "." : ". Para cadastrar mais, ative o plano com o Salão Max."));
        }
    }
}
