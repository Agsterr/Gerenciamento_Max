-- Celulares do app de gestão (usuário do salão) também recebem push; o app do cliente continua sem usuário.
ALTER TABLE push_device ADD COLUMN user_id BIGINT;
ALTER TABLE push_device ADD COLUMN app VARCHAR(10) NOT NULL DEFAULT 'CLIENT';
CREATE INDEX ix_push_device_user ON push_device (user_id);

-- Fila de avisos (outbox): cada linha é um aviso para um celular. O evento que gera o aviso grava a linha
-- na mesma transação; um enviador em segundo plano entrega, tenta de novo se falhar e registra a confirmação
-- do Firebase (SENT) e a do próprio app (RECEIVED).
CREATE TABLE push_outbox (
    id              BIGSERIAL PRIMARY KEY,
    public_id       VARCHAR(36)  NOT NULL UNIQUE,
    tenant_id       BIGINT       NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    device_id       BIGINT       NOT NULL,
    device_token    VARCHAR(512) NOT NULL,
    title           VARCHAR(200) NOT NULL,
    body            VARCHAR(500) NOT NULL,
    data            TEXT         NOT NULL DEFAULT '{}',
    status          VARCHAR(12)  NOT NULL DEFAULT 'PENDING',
    attempts        INT          NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP    NOT NULL DEFAULT now(),
    created_at      TIMESTAMP    NOT NULL DEFAULT now(),
    sent_at         TIMESTAMP,
    received_at     TIMESTAMP,
    last_error      VARCHAR(300),
    dedupe_key      VARCHAR(160)
);
CREATE INDEX ix_push_outbox_due ON push_outbox (status, next_attempt_at);
CREATE UNIQUE INDEX ux_push_outbox_dedupe ON push_outbox (dedupe_key) WHERE dedupe_key IS NOT NULL;
