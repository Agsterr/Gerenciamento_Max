-- Convites: um representante convida um salão (por link ou e-mail do dono). O salão aceita ou recusa.
-- PENDING = enviado; WAITING = o salão aceitou mas outro representante é o titular (sem comissão até o salão parar de
-- pagar e voltar); ACTIVE = este representante é o titular; DECLINED, CANCELED, REPLACED = encerrados.
CREATE TABLE representative_invite (
    id                BIGSERIAL PRIMARY KEY,
    representative_id BIGINT      NOT NULL REFERENCES representative (id) ON DELETE CASCADE,
    salon_id          BIGINT      NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    status            VARCHAR(10) NOT NULL DEFAULT 'PENDING',
    created_at        TIMESTAMP   NOT NULL DEFAULT now(),
    responded_at      TIMESTAMP,
    CONSTRAINT ck_invite_status CHECK (status IN ('PENDING', 'WAITING', 'ACTIVE', 'DECLINED', 'CANCELED', 'REPLACED'))
);
CREATE UNIQUE INDEX ux_invite_open ON representative_invite (representative_id, salon_id) WHERE status IN ('PENDING', 'WAITING');
CREATE INDEX ix_invite_salon ON representative_invite (salon_id, status);

-- Assinatura da loja do representante (R$ 49,90/mês pelo Asaas): 7 dias de teste a partir do primeiro uso.
ALTER TABLE representative ADD COLUMN shop_trial_ends TIMESTAMP;
ALTER TABLE representative ADD COLUMN shop_paid_until DATE;
ALTER TABLE representative ADD COLUMN asaas_customer_id VARCHAR(100);
ALTER TABLE representative ADD COLUMN asaas_subscription_id VARCHAR(100);
CREATE UNIQUE INDEX ux_rep_asaas_customer ON representative (asaas_customer_id) WHERE asaas_customer_id IS NOT NULL;
CREATE UNIQUE INDEX ux_rep_asaas_subscription ON representative (asaas_subscription_id) WHERE asaas_subscription_id IS NOT NULL;

CREATE TABLE shop_subscription_payment (
    id                BIGSERIAL PRIMARY KEY,
    representative_id BIGINT      NOT NULL REFERENCES representative (id) ON DELETE CASCADE,
    external_id       VARCHAR(200) NOT NULL UNIQUE,
    amount_cents      INT         NOT NULL,
    period_end        DATE        NOT NULL,
    status            VARCHAR(10) NOT NULL DEFAULT 'PAID',
    paid_at           TIMESTAMP   NOT NULL
);
