-- Refação: cliente voltou para refazer e não pagou (entra só como custo nos relatórios).
ALTER TABLE appointment ADD COLUMN rework BOOLEAN NOT NULL DEFAULT FALSE;
-- Porcentagem que o salão quer ganhar em cima do custo do produto (opcional).
ALTER TABLE product ADD COLUMN markup_percent NUMERIC(7, 2);
