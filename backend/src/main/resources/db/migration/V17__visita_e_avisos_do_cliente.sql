-- Última vez que o cliente abriu a página do salão (app do cliente) e se aceita avisos de promoção
-- (nulo = ainda não escolheu; o app trata como ligado).
ALTER TABLE customer ADD COLUMN last_seen_at TIMESTAMP;
ALTER TABLE customer ADD COLUMN promo_notifications BOOLEAN;
-- O salão escolhe se a promoção gera aviso no celular dos clientes.
ALTER TABLE promotion ADD COLUMN notify_customers BOOLEAN NOT NULL DEFAULT TRUE;
