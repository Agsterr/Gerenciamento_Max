package com.max.salao.reminder;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

import com.max.salao.shared.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * A cada 5 minutos grava no sino os lembretes de atendimento que venceram (regras de cada usuário).
 * Olha 30 minutos para trás, para não perder aviso se a API reiniciou; a chave do aviso evita repetição.
 */
@Component
public class StaffReminderJob {

    private static final Logger log = LoggerFactory.getLogger(StaffReminderJob.class);
    static final int LOOKBACK_MINUTES = 30;

    private final JdbcTemplate jdbc;
    private final StaffReminderService service;
    private final Clock clock;

    StaffReminderJob(JdbcTemplate jdbc, StaffReminderService service, Clock clock) {
        this.jdbc = jdbc;
        this.service = service;
        this.clock = clock;
    }

    @Scheduled(cron = "${app.staff-reminders.cron:0 */5 * * * *}", zone = "${app.timezone}")
    public void run() {
        List<Long> salons = jdbc.queryForList("""
                select distinct r.tenant_id from user_reminder_rule r join salon s on s.id = r.tenant_id
                where s.blocked = false""", Long.class);
        int sent = 0;
        for (Long id : salons) {
            try {
                TenantContext.set(id);
                // "agora" na hora local do salão (cada salão tem o seu fuso)
                sent += service.notifyDue(LocalDateTime.now(clock).minusMinutes(LOOKBACK_MINUTES));
            } catch (RuntimeException e) {
                log.warn("Lembretes de atendimento do salão {} falharam: {}", id, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (sent > 0) {
            log.info("Lembretes de atendimento: {} avisos", sent);
        }
    }
}
