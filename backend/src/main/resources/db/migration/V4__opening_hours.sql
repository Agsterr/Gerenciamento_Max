-- Horário por dia da semana (ex.: sábado diferente) com pausa opcional (almoço)
CREATE TABLE opening_hours (
    salon_id     BIGINT   NOT NULL REFERENCES salon (id) ON DELETE CASCADE,
    day_of_week  INT      NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    open_time    TIME     NOT NULL,
    close_time   TIME     NOT NULL,
    break_start  TIME,
    break_end    TIME,
    PRIMARY KEY (salon_id, day_of_week)
);

-- Migra o horário único antigo para cada dia de funcionamento
INSERT INTO opening_hours (salon_id, day_of_week, open_time, close_time)
SELECT s.id, d::INT, s.open_time, s.close_time
FROM salon s, unnest(string_to_array(s.work_days, ',')) AS d
WHERE d <> '';

ALTER TABLE salon DROP COLUMN open_time;
ALTER TABLE salon DROP COLUMN close_time;
ALTER TABLE salon DROP COLUMN work_days;
