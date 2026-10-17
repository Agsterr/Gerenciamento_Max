-- Corrige o fuso das datas gravadas até aqui.
--
-- Antes, a API rodava em UTC e convertia para America/Sao_Paulo ao gravar (hibernate.jdbc.time_zone),
-- então os horários informados pelo usuário ficavam 3 h ANTES da hora real no banco (10:00 → 07:00),
-- e os criados pelo banco com now() ficavam em UTC (3 h DEPOIS). A partir desta versão tudo é gravado
-- na hora local do salão. São Paulo não tem horário de verão desde 2019, por isso o ajuste é fixo de 3 h.
--
-- Colunas já certas e que NÃO mudam: created_at de appointment, customer, stock_movement e app_release
-- (preenchidos pelo Java, cuja conversão anulava o deslocamento) e expense.date (só data).

UPDATE appointment SET
    start_at    = start_at    + INTERVAL '3 hours',
    end_at      = end_at      + INTERVAL '3 hours',
    started_at  = started_at  + INTERVAL '3 hours',
    finished_at = finished_at + INTERVAL '3 hours';

UPDATE opening_hours SET
    open_time   = open_time   + INTERVAL '3 hours',
    close_time  = close_time  + INTERVAL '3 hours',
    break_start = break_start + INTERVAL '3 hours',
    break_end   = break_end   + INTERVAL '3 hours';

UPDATE salon SET
    blocked_at = blocked_at + INTERVAL '3 hours',
    created_at = created_at - INTERVAL '3 hours';

UPDATE app_user SET blocked_at = blocked_at + INTERVAL '3 hours';
