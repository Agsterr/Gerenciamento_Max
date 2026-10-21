-- Celulares com o app do cliente que recebem push (Firebase) de cada salão.
CREATE TABLE push_device (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT       NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    token               VARCHAR(512) NOT NULL,
    customer_id         BIGINT REFERENCES customer (id) ON DELETE SET NULL,
    promo_notifications BOOLEAN      NOT NULL DEFAULT TRUE,
    updated_at          TIMESTAMP    NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, token)
);
CREATE INDEX ix_push_device_tenant ON push_device (tenant_id);

-- Quando o aviso da promoção já saiu (não manda duas vezes).
ALTER TABLE promotion ADD COLUMN notified_at TIMESTAMP;
