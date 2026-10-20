package com.max.salao.reminder;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.auth.AppUser;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.notification.NotificationService;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.TenantContext;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Lembretes dos atendimentos para o próprio profissional/usuário do salão. O app de gestão agenda
 * notificações locais com {@link #upcoming}; o {@link StaffReminderJob} grava o mesmo aviso no
 * sino (painel e app), para valer mesmo se a notificação do aparelho falhar.
 */
@Service
public class StaffReminderService {

    static final int MAX_RULES = 5;
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm");

    public record RuleDto(Long id, @Min(0) @Max(7) Integer daysBefore, LocalTime atTime,
                          @Min(5) @Max(10080) Integer minutesBefore) {

        static RuleDto from(UserReminderRule r) {
            return new RuleDto(r.getId(), r.getDaysBefore(), r.getAtTime(), r.getMinutesBefore());
        }
    }

    /** professionalId: agenda que o usuário acompanha (nulo = todos os profissionais). */
    public record Settings(Long professionalId, List<RuleDto> rules) {
    }

    public record Upcoming(Long appointmentId, Long ruleId, LocalDateTime startAt, LocalDateTime remindAt,
                           String title, String message, String key) {
    }

    private final UserReminderRuleRepository rules;
    private final AppUserRepository users;
    private final ProfessionalRepository professionals;
    private final AppointmentRepository appointments;
    private final NotificationService notifications;
    private final Clock clock;

    public StaffReminderService(UserReminderRuleRepository rules, AppUserRepository users,
                                ProfessionalRepository professionals, AppointmentRepository appointments,
                                NotificationService notifications, Clock clock) {
        this.rules = rules;
        this.users = users;
        this.professionals = professionals;
        this.appointments = appointments;
        this.notifications = notifications;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Settings get(Long userId) {
        AppUser user = user(userId);
        return new Settings(user.getProfessionalId(),
                rules.findByUserIdOrderById(userId).stream().map(RuleDto::from).toList());
    }

    @Transactional
    public Settings save(Long userId, Settings req) {
        AppUser user = user(userId);
        if (req.professionalId() != null && professionals.findById(req.professionalId()).isEmpty()) {
            throw new NotFoundException("Profissional não encontrado");
        }
        List<RuleDto> list = req.rules() == null ? List.of() : req.rules();
        if (list.size() > MAX_RULES) {
            throw new BusinessException("No máximo " + MAX_RULES + " lembretes");
        }
        user.setProfessionalId(req.professionalId());
        rules.deleteByUserId(userId);
        rules.flush();
        for (RuleDto dto : list) {
            UserReminderRule r = new UserReminderRule();
            r.setUserId(userId);
            if (dto.minutesBefore() != null) {
                r.setMinutesBefore(dto.minutesBefore());
            } else if (dto.daysBefore() != null && dto.atTime() != null) {
                r.setDaysBefore(dto.daysBefore());
                r.setAtTime(dto.atTime().withSecond(0).withNano(0));
            } else {
                throw new BusinessException("Informe \"minutos antes\" ou \"dias antes\" com o horário");
            }
            rules.save(r);
        }
        return get(userId);
    }

    /** Próximos lembretes do usuário (de agora até {@code days} dias), para o app agendar no aparelho. */
    @Transactional(readOnly = true)
    public List<Upcoming> upcoming(Long userId, int days) {
        LocalDateTime now = LocalDateTime.now(clock);
        return compute(user(userId), rules.findByUserIdOrderById(userId), now, now.plusDays(days));
    }

    /** Lembretes com horário de aviso em (from, to], de atendimentos que ainda não começaram. */
    List<Upcoming> compute(AppUser user, List<UserReminderRule> userRules, LocalDateTime from, LocalDateTime to) {
        if (userRules.isEmpty()) {
            return List.of();
        }
        LocalDateTime now = LocalDateTime.now(clock);
        // o aviso mais adiantado é de até 8 dias (7 dias antes às 00:00)
        List<Appointment> candidates = appointments.findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(
                        now, to.plusDays(9)).stream()
                .filter(a -> a.getStatus().isOpen())
                .filter(a -> user.getProfessionalId() == null
                        || a.getProfessional().getId().equals(user.getProfessionalId()))
                .toList();
        List<Upcoming> result = new ArrayList<>();
        for (Appointment a : candidates) {
            for (UserReminderRule r : userRules) {
                LocalDateTime at = r.remindAt(a.getStartAt());
                if (at.isAfter(from) && !at.isAfter(to)) {
                    result.add(new Upcoming(a.getId(), r.getId(), a.getStartAt(), at, title(a),
                            NotificationService.describe(a), "staff:" + user.getId() + ":" + a.getId() + ":" + r.getId()
                            + ":" + a.getStartAt()));
                }
            }
        }
        result.sort(Comparator.comparing(Upcoming::remindAt));
        return result;
    }

    /** Grava no sino os lembretes que venceram desde {@code since} (chamado pelo job, já no tenant). */
    @Transactional
    public int notifyDue(LocalDateTime since) {
        LocalDateTime now = LocalDateTime.now(clock);
        int sent = 0;
        List<UserReminderRule> all = rules.findAllByOrderByUserIdAscIdAsc();
        for (Long userId : all.stream().map(UserReminderRule::getUserId).distinct().toList()) {
            AppUser user = users.findById(userId).orElse(null);
            if (user == null || !user.isActive() || user.isBlocked()
                    || !TenantContext.get().equals(user.getSalonId())) {
                continue;
            }
            List<UserReminderRule> userRules = all.stream().filter(r -> r.getUserId().equals(userId)).toList();
            for (Upcoming u : compute(user, userRules, since, now)) {
                Appointment a = appointments.findById(u.appointmentId()).orElseThrow();
                if (notifications.notifyUser(userId, u.key(), a, u.title())) {
                    sent++;
                }
            }
        }
        return sent;
    }

    private static String title(Appointment a) {
        return "Atendimento às " + TIME.format(a.getStartAt()) + ": " + a.getCustomer().getName();
    }

    private AppUser user(Long userId) {
        return users.findById(userId)
                .filter(u -> TenantContext.get().equals(u.getSalonId()))
                .orElseThrow(() -> new NotFoundException("Usuário não encontrado"));
    }
}
