-- A cobrança pelo site passa a ser pelo Asaas (Pix, boleto e cartão), não pelo Stripe.
ALTER TABLE salon RENAME COLUMN stripe_customer_id TO asaas_customer_id;
ALTER TABLE salon RENAME COLUMN stripe_subscription_id TO asaas_subscription_id;
ALTER INDEX ux_salon_stripe_customer RENAME TO ux_salon_asaas_customer;
-- Link de pagamento criado para o salão: o aviso do Asaas traz o id do link, que liga o pagamento ao salão.
ALTER TABLE salon ADD COLUMN asaas_link_id VARCHAR(100);
CREATE UNIQUE INDEX ux_salon_asaas_link ON salon (asaas_link_id) WHERE asaas_link_id IS NOT NULL;
CREATE INDEX ix_salon_asaas_subscription ON salon (asaas_subscription_id) WHERE asaas_subscription_id IS NOT NULL;
