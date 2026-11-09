package com.max.salao.notification;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDateTime;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Limpeza diária dos avisos do sino (todos os salões): os lidos há mais de {@code keep-read-days} dias e qualquer um com mais
 * de {@code keep-days} dias saem, para o histórico não crescer sem fim.
 */
@Component
class NotificationCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(NotificationCleanupJob.class);

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final int keepReadDays;
    private final int keepDays;

    NotificationCleanupJob(JdbcTemplate jdbc, Clock clock, @Value("${app.notifications.keep-read-days:30}") int keepReadDays,
                           @Value("${app.notifications.keep-days:90}") int keepDays) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.keepReadDays = keepReadDays;
        this.keepDays = keepDays;
    }

    @Scheduled(cron = "${app.notifications.cleanup-cron:0 30 3 * * *}", zone = "${app.timezone}")
    void run() {
        cleanup();
    }

    /** Retorna quantos avisos foram apagados. */
    int cleanup() {
        LocalDateTime now = LocalDateTime.now(clock);
        int deleted = jdbc.update("DELETE FROM notification WHERE (read_at IS NOT NULL AND created_at < ?) OR created_at < ?",
                Timestamp.valueOf(now.minusDays(keepReadDays)), Timestamp.valueOf(now.minusDays(keepDays)));
        if (deleted > 0) {
            log.info("Avisos antigos apagados: {}", deleted);
        }
        return deleted;
    }
}
