-- Loja do representante: ele cadastra produtos e equipamentos; os salões que ele indicou compram.
-- cost_cents = valor real dele (o que o salão deve a ele); suggested_cents = preço sugerido para vender ao cliente
-- (a diferença é o ganho do salão). Só se registra o pagamento: a cobrança é combinada fora do app.
ALTER TABLE salon ADD COLUMN neighborhood VARCHAR(120);
ALTER TABLE salon ADD COLUMN city VARCHAR(120);

CREATE TABLE shop_product (
    id               BIGSERIAL PRIMARY KEY,
    representative_id BIGINT       NOT NULL REFERENCES representative (id) ON DELETE CASCADE,
    name             VARCHAR(160) NOT NULL,
    description      VARCHAR(1000),
    kind             VARCHAR(12)  NOT NULL DEFAULT 'PRODUCT',
    category         VARCHAR(60),
    cost_cents       INT          NOT NULL,
    suggested_cents  INT          NOT NULL,
    promo_cents      INT,
    promo_until      DATE,
    image_url        VARCHAR(500),
    thumb_url        VARCHAR(500),
    active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP    NOT NULL DEFAULT now(),
    CONSTRAINT ck_shop_product_kind CHECK (kind IN ('PRODUCT', 'EQUIPMENT')),
    CONSTRAINT ck_shop_product_price CHECK (cost_cents >= 0 AND suggested_cents >= 0 AND (promo_cents IS NULL OR promo_cents >= 0))
);
CREATE INDEX ix_shop_product_rep ON shop_product (representative_id, active);

-- O salão escolhe quais produtos do representante aparecem na vitrine dele.
CREATE TABLE shop_hidden (
    salon_id   BIGINT NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES shop_product (id) ON DELETE CASCADE,
    PRIMARY KEY (salon_id, product_id)
);

CREATE TABLE shop_order (
    id                BIGSERIAL PRIMARY KEY,
    representative_id BIGINT       NOT NULL REFERENCES representative (id) ON DELETE CASCADE,
    salon_id          BIGINT       NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    salon_name        VARCHAR(200) NOT NULL,
    contact_name      VARCHAR(120) NOT NULL,
    phone             VARCHAR(30),
    address           VARCHAR(300),
    neighborhood      VARCHAR(120),
    city              VARCHAR(120),
    note              VARCHAR(500),
    status            VARCHAR(12)  NOT NULL DEFAULT 'PENDING',
    total_cents       BIGINT       NOT NULL,
    created_at        TIMESTAMP    NOT NULL DEFAULT now(),
    updated_at        TIMESTAMP    NOT NULL DEFAULT now(),
    CONSTRAINT ck_shop_order_status CHECK (status IN ('PENDING', 'PREPARING', 'SHIPPED', 'DELIVERED', 'CANCELED'))
);
CREATE INDEX ix_shop_order_rep ON shop_order (representative_id, status);
CREATE INDEX ix_shop_order_salon ON shop_order (salon_id, created_at DESC);

CREATE TABLE shop_order_item (
    id              BIGSERIAL PRIMARY KEY,
    order_id        BIGINT       NOT NULL REFERENCES shop_order (id) ON DELETE CASCADE,
    product_id      BIGINT       REFERENCES shop_product (id) ON DELETE SET NULL,
    name            VARCHAR(160) NOT NULL,
    quantity        INT          NOT NULL CHECK (quantity > 0),
    unit_cents      INT          NOT NULL,
    suggested_cents INT          NOT NULL
);
CREATE INDEX ix_shop_order_item_order ON shop_order_item (order_id);

-- Baixas: o que o salão já pagou ao representante (Pix, dinheiro, desconto de comissão...).
CREATE TABLE shop_payment (
    id           BIGSERIAL PRIMARY KEY,
    order_id     BIGINT       NOT NULL REFERENCES shop_order (id) ON DELETE CASCADE,
    amount_cents INT          NOT NULL CHECK (amount_cents > 0),
    method       VARCHAR(40)  NOT NULL,
    note         VARCHAR(300),
    created_at   TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX ix_shop_payment_order ON shop_payment (order_id);
