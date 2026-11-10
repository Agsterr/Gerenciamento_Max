-- O salão marca produtos do representante para as clientes dele verem (vitrine pública). O pedido da cliente vai direto
-- para o representante; a diferença entre o preço sugerido e o valor do salão vira comissão do salão.
CREATE TABLE shop_showcase (
    salon_id   BIGINT NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES shop_product (id) ON DELETE CASCADE,
    PRIMARY KEY (salon_id, product_id)
);

ALTER TABLE shop_order ADD COLUMN origin VARCHAR(10) NOT NULL DEFAULT 'SALON';
ALTER TABLE shop_order ADD COLUMN commission_cents BIGINT NOT NULL DEFAULT 0;
ALTER TABLE shop_order ADD COLUMN commission_settled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE shop_order ADD CONSTRAINT ck_shop_order_origin CHECK (origin IN ('SALON', 'CUSTOMER'));
