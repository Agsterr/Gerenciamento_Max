-- Parâmetros da calculadora de preços (por salão)
ALTER TABLE salon ADD COLUMN card_fee_percent      NUMERIC(5, 2)  NOT NULL DEFAULT 4;
ALTER TABLE salon ADD COLUMN target_margin_percent NUMERIC(5, 2)  NOT NULL DEFAULT 20;
ALTER TABLE salon ADD COLUMN occupancy_percent     NUMERIC(5, 2)  NOT NULL DEFAULT 70;
-- Custo fixo mensal informado manualmente; nulo = média das despesas lançadas
ALTER TABLE salon ADD COLUMN fixed_monthly_cost    NUMERIC(12, 2);
