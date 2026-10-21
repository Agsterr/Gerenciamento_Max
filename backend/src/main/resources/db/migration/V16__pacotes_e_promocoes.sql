-- Pacote (kit): um serviço formado por outros, com desconto em % sobre a soma.
ALTER TABLE service_item ADD COLUMN kit_discount_percent NUMERIC(5, 2);

CREATE TABLE service_kit_item (
    kit_id     BIGINT NOT NULL REFERENCES service_item (id) ON DELETE CASCADE,
    service_id BIGINT NOT NULL REFERENCES service_item (id) ON DELETE CASCADE,
    PRIMARY KEY (kit_id, service_id)
);

-- Promoção: desconto em % em serviços (ou em todos) para horários dentro do período.
CREATE TABLE promotion (
    id               BIGSERIAL PRIMARY KEY,
    tenant_id        BIGINT        NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    name             VARCHAR(80)   NOT NULL,
    description      VARCHAR(300),
    discount_percent NUMERIC(5, 2) NOT NULL,
    starts_on        DATE          NOT NULL,
    ends_on          DATE          NOT NULL,
    active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT now()
);
CREATE INDEX ix_promotion_tenant ON promotion (tenant_id);

CREATE TABLE promotion_service (
    promotion_id BIGINT NOT NULL REFERENCES promotion (id) ON DELETE CASCADE,
    service_id   BIGINT NOT NULL REFERENCES service_item (id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, service_id)
);

ALTER TABLE appointment ADD COLUMN promotion_id BIGINT REFERENCES promotion (id) ON DELETE SET NULL;
ALTER TABLE appointment ADD COLUMN discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0;
