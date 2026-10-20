package com.max.salao.reminder;

import java.util.List;

import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.notification.NotificationService;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Todo dia de manhã avisa cada salão (sino do painel/app) de quantos clientes ainda precisam
 * confirmar o horário de amanhã/depois de amanhã. Leve: uma consulta por salão com lembrete ligado.
 */
@Component
public class ReminderJob {

    private static final Logger log = LoggerFactory.getLogger(ReminderJob.class);

    private final JdbcTemplate jdbc;
    private final SalonService salons;
    private final ReminderService reminders;
    private final NotificationService notifications;

    ReminderJob(JdbcTemplate jdbc, SalonService salons, ReminderService reminders, NotificationService notifications) {
        this.jdbc = jdbc;
        this.salons = salons;
        this.reminders = reminders;
        this.notifications = notifications;
    }

    @Scheduled(cron = "${app.reminders.cron:0 0 8 * * *}", zone = "${app.timezone}")
    public void run() {
        List<Long> ids = jdbc.queryForList(
                "select id from salon where reminder_mode <> 'OFF' and blocked = false", Long.class);
        int notified = 0;
        for (Long id : ids) {
            try {
                TenantContext.set(id);
                if (notifySalon()) {
                    notified++;
                }
            } catch (RuntimeException e) {
                log.warn("Lembretes do salão {} falharam: {}", id, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        log.info("Lembretes: {} salões avisados", notified);
    }

    /** Roda dentro do tenant já definido. */
    boolean notifySalon() {
        Salon salon = salons.current();
        long pending = reminders.due(salon).stream()
                .filter(a -> a.getStatus() == AppointmentStatus.SCHEDULED && a.getReminderSentAt() == null)
                .count();
        List<Integer> days = salon.getReminderMode().days();
        String when = days.size() > 1 ? "de amanhã e depois de amanhã"
                : days.get(0) == 1 ? "de amanhã" : "de depois de amanhã";
        return notifications.notifyReminders(pending, when);
    }
}
