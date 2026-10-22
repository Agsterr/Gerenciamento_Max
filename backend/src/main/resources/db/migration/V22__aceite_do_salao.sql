-- O salão aceita (confirma) os agendamentos feitos pelo cliente; até lá ficam "aguardando confirmação".
-- Quem já existia conta como aceito; os criados pelo próprio salão nascem aceitos.
ALTER TABLE appointment ADD COLUMN salon_confirmed_at TIMESTAMP;
UPDATE appointment SET salon_confirmed_at = now();
