-- APKs publicados fora da loja (atualização OTA), um histórico curto por app
CREATE TABLE app_release (
    id               BIGSERIAL PRIMARY KEY,
    app              VARCHAR(20)   NOT NULL,
    version_name     VARCHAR(32)   NOT NULL,
    version_code     INT           NOT NULL,
    file_name        VARCHAR(120)  NOT NULL,
    file_size_bytes  BIGINT        NOT NULL,
    sha256           VARCHAR(64)   NOT NULL,
    release_notes    VARCHAR(2000),
    force_update     BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP     NOT NULL DEFAULT now(),
    CONSTRAINT uq_app_release_version UNIQUE (app, version_code)
);

-- Bloqueio de salões e usuários pelo administrador da plataforma
ALTER TABLE salon ADD COLUMN blocked        BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE salon ADD COLUMN blocked_reason VARCHAR(300);
ALTER TABLE salon ADD COLUMN blocked_at     TIMESTAMP;

ALTER TABLE app_user ADD COLUMN blocked        BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE app_user ADD COLUMN blocked_reason VARCHAR(300);
ALTER TABLE app_user ADD COLUMN blocked_at     TIMESTAMP;

-- O administrador da plataforma não pertence a nenhum salão
ALTER TABLE app_user ALTER COLUMN salon_id DROP NOT NULL;
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_salon
    CHECK (salon_id IS NOT NULL OR role = 'PLATFORM_ADMIN');
