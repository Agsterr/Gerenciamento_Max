-- A assinatura pelo site usa cliente + assinatura do Asaas (como o sistema de estoque), não link de pagamento.
DROP INDEX IF EXISTS ux_salon_asaas_link;
ALTER TABLE salon DROP COLUMN IF EXISTS asaas_link_id;
