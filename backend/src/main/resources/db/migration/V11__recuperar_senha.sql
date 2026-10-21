-- Links de recuperação de senha: guarda só o hash do token, que vale por 1 hora e uma única vez.
CREATE TABLE password_reset (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    token_hash VARCHAR(64)  NOT NULL UNIQUE,
    expires_at TIMESTAMP    NOT NULL,
    used_at    TIMESTAMP,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX ix_password_reset_user ON password_reset (user_id);
