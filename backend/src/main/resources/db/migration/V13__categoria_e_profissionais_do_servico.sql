-- Categoria do serviço (Cabelo, Unhas...) e quais profissionais fazem cada serviço.
-- Sem linhas em service_professional = qualquer profissional faz o serviço.
ALTER TABLE service_item ADD COLUMN category VARCHAR(40);

CREATE TABLE service_professional (
    service_id      BIGINT NOT NULL REFERENCES service_item (id) ON DELETE CASCADE,
    professional_id BIGINT NOT NULL REFERENCES professional (id) ON DELETE CASCADE,
    PRIMARY KEY (service_id, professional_id)
);
