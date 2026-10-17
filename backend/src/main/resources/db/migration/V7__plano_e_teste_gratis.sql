-- Teste grátis com prazo e limites; o plano pago é ativado pelo administrador da plataforma.
ALTER TABLE salon ADD COLUMN plan VARCHAR(10) NOT NULL DEFAULT 'TRIAL';
ALTER TABLE salon ADD COLUMN trial_ends_at TIMESTAMP;
ALTER TABLE salon ADD COLUMN paid_until DATE;

-- Salões que já existiam ganham 14 dias de teste a partir de agora (o admin marca os pagantes como "Pago").
UPDATE salon SET trial_ends_at = now() + INTERVAL '14 days';
ALTER TABLE salon ALTER COLUMN trial_ends_at SET NOT NULL;

CREATE TABLE platform_setting (
    name  VARCHAR(40) PRIMARY KEY,
    value VARCHAR(300) NOT NULL
);
