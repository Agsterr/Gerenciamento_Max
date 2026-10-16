-- Multi-tenant por coluna: toda tabela de negócio tem tenant_id -> salon.id

CREATE TABLE salon (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    slug          VARCHAR(60)  NOT NULL UNIQUE,
    phone         VARCHAR(30),
    address       VARCHAR(200),
    open_time     TIME         NOT NULL DEFAULT '09:00',
    close_time    TIME         NOT NULL DEFAULT '19:00',
    work_days     VARCHAR(20)  NOT NULL DEFAULT '2,3,4,5,6',
    slot_minutes  INT          NOT NULL DEFAULT 30,
    created_at    TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
    id             BIGSERIAL PRIMARY KEY,
    salon_id       BIGINT       NOT NULL REFERENCES salon (id),
    name           VARCHAR(120) NOT NULL,
    email          VARCHAR(160) NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    role           VARCHAR(20)  NOT NULL,
    active         BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE professional (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT        NOT NULL REFERENCES salon (id),
    name                VARCHAR(120)  NOT NULL,
    phone               VARCHAR(30),
    commission_percent  NUMERIC(5, 2) NOT NULL DEFAULT 0,
    active              BOOLEAN       NOT NULL DEFAULT TRUE
);
CREATE INDEX ix_professional_tenant ON professional (tenant_id);

CREATE TABLE service_item (
    id                BIGSERIAL PRIMARY KEY,
    tenant_id         BIGINT         NOT NULL REFERENCES salon (id),
    name              VARCHAR(120)   NOT NULL,
    description       VARCHAR(300),
    duration_minutes  INT            NOT NULL,
    price             NUMERIC(12, 2) NOT NULL,
    cost              NUMERIC(12, 2) NOT NULL DEFAULT 0,
    active            BOOLEAN        NOT NULL DEFAULT TRUE
);
CREATE INDEX ix_service_item_tenant ON service_item (tenant_id);

CREATE TABLE customer (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES salon (id),
    name       VARCHAR(120) NOT NULL,
    phone      VARCHAR(30)  NOT NULL,
    email      VARCHAR(160),
    notes      VARCHAR(500),
    created_at TIMESTAMP    NOT NULL DEFAULT now(),
    CONSTRAINT uq_customer_phone UNIQUE (tenant_id, phone)
);

CREATE TABLE product (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT         NOT NULL REFERENCES salon (id),
    name        VARCHAR(120)   NOT NULL,
    cost_price  NUMERIC(12, 2) NOT NULL DEFAULT 0,
    sale_price  NUMERIC(12, 2) NOT NULL DEFAULT 0,
    stock       NUMERIC(12, 3) NOT NULL DEFAULT 0,
    min_stock   NUMERIC(12, 3) NOT NULL DEFAULT 0,
    unit        VARCHAR(10)    NOT NULL DEFAULT 'un',
    active      BOOLEAN        NOT NULL DEFAULT TRUE
);
CREATE INDEX ix_product_tenant ON product (tenant_id);

CREATE TABLE appointment (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT         NOT NULL REFERENCES salon (id),
    customer_id         BIGINT         NOT NULL REFERENCES customer (id),
    professional_id     BIGINT         NOT NULL REFERENCES professional (id),
    service_id          BIGINT         NOT NULL REFERENCES service_item (id),
    start_at            TIMESTAMP      NOT NULL,
    end_at              TIMESTAMP      NOT NULL,
    status              VARCHAR(20)    NOT NULL,
    price               NUMERIC(12, 2) NOT NULL,
    service_cost        NUMERIC(12, 2) NOT NULL DEFAULT 0,
    commission_amount   NUMERIC(12, 2) NOT NULL DEFAULT 0,
    started_at          TIMESTAMP,
    finished_at         TIMESTAMP,
    notes               VARCHAR(500),
    source              VARCHAR(10)    NOT NULL,
    public_token        VARCHAR(40)    NOT NULL UNIQUE,
    created_at          TIMESTAMP      NOT NULL DEFAULT now()
);
CREATE INDEX ix_appointment_agenda ON appointment (tenant_id, start_at);
CREATE INDEX ix_appointment_professional ON appointment (professional_id, start_at);
CREATE INDEX ix_appointment_customer ON appointment (customer_id);

CREATE TABLE stock_movement (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT         NOT NULL REFERENCES salon (id),
    product_id      BIGINT         NOT NULL REFERENCES product (id),
    appointment_id  BIGINT REFERENCES appointment (id),
    type            VARCHAR(10)    NOT NULL,
    quantity        NUMERIC(12, 3) NOT NULL,
    unit_cost       NUMERIC(12, 2) NOT NULL,
    unit_price      NUMERIC(12, 2),
    created_at      TIMESTAMP      NOT NULL DEFAULT now()
);
CREATE INDEX ix_stock_movement_tenant ON stock_movement (tenant_id, created_at);

CREATE TABLE expense (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT         NOT NULL REFERENCES salon (id),
    description  VARCHAR(200)   NOT NULL,
    category     VARCHAR(40)    NOT NULL,
    amount       NUMERIC(12, 2) NOT NULL,
    date         DATE           NOT NULL
);
CREATE INDEX ix_expense_tenant ON expense (tenant_id, date);
