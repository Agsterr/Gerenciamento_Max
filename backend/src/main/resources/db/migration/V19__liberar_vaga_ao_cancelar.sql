-- O salão escolhe se a vaga volta para a agenda quando o CLIENTE cancela pelo link/app.
-- Padrão ligado: é como já funcionava. Desligado, o horário continua bloqueado e o salão só recebe o aviso.
ALTER TABLE salon ADD COLUMN release_slot_on_cancel BOOLEAN NOT NULL DEFAULT TRUE;

-- Agendamento cancelado pelo cliente cujo horário o salão manteve bloqueado.
ALTER TABLE appointment ADD COLUMN slot_held BOOLEAN NOT NULL DEFAULT FALSE;
