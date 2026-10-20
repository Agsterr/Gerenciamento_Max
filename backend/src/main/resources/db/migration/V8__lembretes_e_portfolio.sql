-- Lembrete para o cliente confirmar o agendamento: OFF, ONE_DAY, TWO_DAYS ou BOTH (dias antes).
ALTER TABLE salon ADD COLUMN reminder_mode VARCHAR(10) NOT NULL DEFAULT 'ONE_DAY';

-- Quando o salão mandou o lembrete pelo WhatsApp e quando o cliente confirmou pelo link/app.
ALTER TABLE appointment ADD COLUMN reminder_sent_at TIMESTAMP;
ALTER TABLE appointment ADD COLUMN customer_confirmed_at TIMESTAMP;

-- Portfólio: fotos dos trabalhos do salão (arquivos no Cloudflare R2 ou no disco do servidor).
CREATE TABLE portfolio_photo (
    id               BIGSERIAL PRIMARY KEY,
    tenant_id        BIGINT       NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    service_id       BIGINT REFERENCES service_item (id) ON DELETE SET NULL,
    professional_id  BIGINT REFERENCES professional (id) ON DELETE SET NULL,
    caption          VARCHAR(200),
    image_key        VARCHAR(200) NOT NULL,
    thumb_key        VARCHAR(200) NOT NULL,
    image_url        VARCHAR(500) NOT NULL,
    thumb_url        VARCHAR(500) NOT NULL,
    width            INT          NOT NULL,
    height           INT          NOT NULL,
    size_bytes       BIGINT       NOT NULL,
    position         INT          NOT NULL DEFAULT 0,
    created_at       TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX ix_portfolio_photo_tenant ON portfolio_photo (tenant_id, position, id);
