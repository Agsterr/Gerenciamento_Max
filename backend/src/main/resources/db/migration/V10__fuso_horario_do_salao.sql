-- Cada salão tem o seu fuso (o Brasil tem 4: Noronha, Brasília, Amazonas/MT/MS/RO/RR e Acre).
-- Salões existentes ficam em Brasília, como já eram tratados.
ALTER TABLE salon ADD COLUMN timezone VARCHAR(40) NOT NULL DEFAULT 'America/Sao_Paulo';
