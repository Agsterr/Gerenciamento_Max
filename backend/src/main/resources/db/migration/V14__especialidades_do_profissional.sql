-- Categorias que o profissional atende (Cabelo, Unhas...). Sem linhas = atende todas.
CREATE TABLE professional_category (
    professional_id BIGINT      NOT NULL REFERENCES professional (id) ON DELETE CASCADE,
    category        VARCHAR(40) NOT NULL,
    PRIMARY KEY (professional_id, category)
);
