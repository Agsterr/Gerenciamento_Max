-- Anotações do profissional no atendimento (privadas do salão: tinta usada, tipo de corte...)
ALTER TABLE appointment ADD COLUMN service_notes VARCHAR(1000);

-- Avisos para o salão (agendamento online novo, cancelado ou remarcado pelo cliente)
CREATE TABLE notification (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT       NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    type            VARCHAR(20)  NOT NULL,
    appointment_id  BIGINT REFERENCES appointment (id) ON DELETE CASCADE,
    title           VARCHAR(120) NOT NULL,
    message         VARCHAR(300) NOT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT now(),
    read_at         TIMESTAMP
);
CREATE INDEX ix_notification_tenant ON notification (tenant_id, created_at DESC);
