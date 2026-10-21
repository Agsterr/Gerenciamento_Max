-- Assinatura pela Google Play: a compra (token) fica ligada ao salão; um token nunca serve a dois salões.
ALTER TABLE salon ADD COLUMN play_purchase_token VARCHAR(400);
ALTER TABLE salon ADD COLUMN play_checked_at TIMESTAMP;
-- Libera a tela "Assinar" só para este salão (teste da compra antes de ligar para todos).
ALTER TABLE salon ADD COLUMN billing_preview BOOLEAN NOT NULL DEFAULT FALSE;
CREATE UNIQUE INDEX ux_salon_play_token ON salon (play_purchase_token) WHERE play_purchase_token IS NOT NULL;
