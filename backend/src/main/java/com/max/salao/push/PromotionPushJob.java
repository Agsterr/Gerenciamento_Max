package com.max.salao.push;

import java.util.List;

import com.max.salao.shared.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** A cada poucos minutos manda o push das promoções que começaram (e ainda não foram avisadas). */
@Component
public class PromotionPushJob {

    private static final Logger log = LoggerFactory.getLogger(PromotionPushJob.class);

    private final JdbcTemplate jdbc;
    private final PromotionPushService service;
    private final PushProperties props;

    PromotionPushJob(JdbcTemplate jdbc, PromotionPushService service, PushProperties props) {
        this.jdbc = jdbc;
        this.service = service;
        this.props = props;
    }

    @Scheduled(cron = "${app.push.cron:0 */5 * * * *}", zone = "${app.timezone}")
    public void run() {
        if (!props.configured()) {
            return;
        }
        List<Long> ids = jdbc.queryForList("""
                select distinct p.tenant_id from promotion p join salon s on s.id = p.tenant_id
                where p.active and p.notify_customers and p.notified_at is null
                  and p.starts_on <= current_date + 1 and p.ends_on >= current_date - 1 and s.blocked = false""", Long.class);
        int sent = 0;
        for (Long id : ids) {
            try {
                TenantContext.set(id);
                sent += service.sendDue();
            } catch (RuntimeException e) {
                log.warn("Push de promoções do salão {} falhou: {}", id, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
        if (sent > 0) {
            log.info("Push de promoções: {} enviados", sent);
        }
    }
}
