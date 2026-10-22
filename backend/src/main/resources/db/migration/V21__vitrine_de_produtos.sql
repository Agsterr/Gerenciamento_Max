-- Produtos à venda aparecem na vitrine do cliente (página do salão e app), a menos que o salão desligue.
ALTER TABLE product ADD COLUMN showcase BOOLEAN NOT NULL DEFAULT TRUE;
