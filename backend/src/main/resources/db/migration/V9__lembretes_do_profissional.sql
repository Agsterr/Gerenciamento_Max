-- Lembrete dos atendimentos para o próprio profissional/usuário do salão.
-- Qual agenda o usuário acompanha (nulo = todos os profissionais do salão).
ALTER TABLE app_user ADD COLUMN professional_id BIGINT REFERENCES professional (id) ON DELETE SET NULL;

-- Regras: "N dias antes, às HH:mm" (days_before + at_time) ou "X minutos antes" (minutes_before).
CREATE TABLE user_reminder_rule (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT  NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    user_id         BIGINT  NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    days_before     INT,
    at_time         TIME,
    minutes_before  INT,
    CONSTRAINT ck_user_reminder_rule CHECK (
        (minutes_before IS NOT NULL AND days_before IS NULL AND at_time IS NULL)
        OR (minutes_before IS NULL AND days_before IS NOT NULL AND at_time IS NOT NULL))
);
CREATE INDEX ix_user_reminder_rule_user ON user_reminder_rule (tenant_id, user_id);

-- Avisos só para um usuário (nulo = toda a equipe) e chave para o job não repetir o mesmo aviso.
ALTER TABLE notification ADD COLUMN user_id BIGINT REFERENCES app_user (id) ON DELETE CASCADE;
ALTER TABLE notification ADD COLUMN dedup_key VARCHAR(100);
CREATE UNIQUE INDEX ux_notification_dedup ON notification (tenant_id, dedup_key);
