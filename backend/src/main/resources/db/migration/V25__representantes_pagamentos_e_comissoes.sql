-- Representantes: indicam salões por um link com código; ganham uma comissão fixa por mensalidade paga.
-- O usuário do representante não pertence a nenhum salão.
ALTER TABLE app_user DROP CONSTRAINT ck_app_user_salon;
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_salon
    CHECK (salon_id IS NOT NULL OR role IN ('PLATFORM_ADMIN', 'REPRESENTATIVE'));

CREATE TABLE representative (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL UNIQUE REFERENCES app_user (id) ON DELETE CASCADE,
    code       VARCHAR(20)  NOT NULL UNIQUE,
    pix_key    VARCHAR(120),
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);

-- Quem indicou o salão (definido uma vez, no cadastro) e a assinatura pelo site (Stripe).
ALTER TABLE salon ADD COLUMN referrer_id BIGINT REFERENCES representative (id) ON DELETE SET NULL;
ALTER TABLE salon ADD COLUMN stripe_customer_id VARCHAR(100);
ALTER TABLE salon ADD COLUMN stripe_subscription_id VARCHAR(100);
CREATE UNIQUE INDEX ux_salon_stripe_customer ON salon (stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
CREATE INDEX ix_salon_referrer ON salon (referrer_id) WHERE referrer_id IS NOT NULL;

-- Cada mensalidade paga (site ou Play). Estorno marca REFUNDED. Único por provedor + código externo.
CREATE TABLE subscription_payment (
    id           BIGSERIAL PRIMARY KEY,
    salon_id     BIGINT       REFERENCES salon (id) ON DELETE SET NULL,
    salon_name   VARCHAR(200) NOT NULL,
    provider     VARCHAR(10)  NOT NULL,
    external_id  VARCHAR(200) NOT NULL,
    payment_ref  VARCHAR(200),
    amount_cents INT          NOT NULL,
    period_end   DATE,
    status       VARCHAR(10)  NOT NULL DEFAULT 'PAID',
    paid_at      TIMESTAMP    NOT NULL,
    refunded_at  TIMESTAMP,
    CONSTRAINT ux_payment_external UNIQUE (provider, external_id)
);
CREATE INDEX ix_payment_salon ON subscription_payment (salon_id);
CREATE INDEX ix_payment_ref ON subscription_payment (payment_ref) WHERE payment_ref IS NOT NULL;

-- Uma comissão por pagamento de salão indicado. PENDING = a receber (ainda sem repasse); PAID = repassada;
-- REVERSED = o pagamento foi estornado/contestado e o representante perde a comissão.
CREATE TABLE commission (
    id                BIGSERIAL PRIMARY KEY,
    representative_id BIGINT       NOT NULL REFERENCES representative (id) ON DELETE CASCADE,
    salon_id          BIGINT       REFERENCES salon (id) ON DELETE SET NULL,
    salon_name        VARCHAR(200) NOT NULL,
    payment_id        BIGINT       NOT NULL UNIQUE REFERENCES subscription_payment (id) ON DELETE CASCADE,
    amount_cents      INT          NOT NULL,
    status            VARCHAR(10)  NOT NULL DEFAULT 'PENDING',
    created_at        TIMESTAMP    NOT NULL DEFAULT now(),
    paid_at           TIMESTAMP,
    reversed_at       TIMESTAMP
);
CREATE INDEX ix_commission_rep ON commission (representative_id, status);
