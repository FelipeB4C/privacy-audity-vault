CREATE SCHEMA IF NOT EXISTS vault_data;
CREATE SCHEMA IF NOT EXISTS audit_log;


CREATE TABLE IF NOT EXISTS vault_data.encryption_key_reference (
                                                                   key_reference_id     UUID PRIMARY KEY,
                                                                   kek_key_id           VARCHAR(255) NOT NULL,
    encrypted_dek_blob   BYTEA NOT NULL,
    issued_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_revoked           BOOLEAN NOT NULL DEFAULT false
    );

CREATE TABLE IF NOT EXISTS vault_data.vault_record (
                                                       applicant_id               UUID PRIMARY KEY,
                                                       sin_ciphertext             BYTEA NOT NULL,
                                                       full_address_ciphertext    BYTEA,
                                                       key_reference_id           UUID NOT NULL
                                                   REFERENCES vault_data.encryption_key_reference(key_reference_id),
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_shredded                BOOLEAN NOT NULL DEFAULT false
    );


CREATE INDEX IF NOT EXISTS idx_vault_record_active
    ON vault_data.vault_record(applicant_id)
    WHERE is_shredded = false;

-- ---------------------------------------------------------------------
-- audit_log
-- ---------------------------------------------------------------------

-- A PK de tabela particionada PRECISA incluir a coluna da chave de particao
-- (occurred_at), por isso a PK composta.
CREATE TABLE IF NOT EXISTS audit_log.audit_log_entry (
                                                         audit_id             UUID NOT NULL,
                                                         applicant_id         UUID NOT NULL,
                                                         operation_type       VARCHAR(30) NOT NULL,   -- READ, WRITE, SHRED
    requesting_service   VARCHAR(100) NOT NULL,
    occurred_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (audit_id, occurred_at)
    ) PARTITION BY RANGE (occurred_at);

-- Particionamento mensal: mantem consultas recentes rapidas e facilita
-- retencao/arquivamento conforme a politica de retencao da Loi 25.
CREATE TABLE IF NOT EXISTS audit_log.audit_log_entry_2026_10
    PARTITION OF audit_log.audit_log_entry
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

-- Rede de seguranca: evita falha de INSERT quando nao existe particao para a data.
-- Use um job (pg_partman/cron) para criar as particoes mensais com antecedencia.
CREATE TABLE IF NOT EXISTS audit_log.audit_log_entry_default
    PARTITION OF audit_log.audit_log_entry DEFAULT;

CREATE INDEX IF NOT EXISTS idx_audit_log_applicant_id
    ON audit_log.audit_log_entry(applicant_id);

-- ---------------------------------------------------------------------
-- Imutabilidade em nivel de banco (append-only)
-- ---------------------------------------------------------------------

REVOKE UPDATE, DELETE, TRUNCATE ON audit_log.audit_log_entry FROM PUBLIC;

CREATE OR REPLACE FUNCTION audit_log.reject_mutation() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_log_entry e append-only: UPDATE/DELETE/TRUNCATE nao permitidos (Loi 25 compliance)';
END;
$$ LANGUAGE plpgsql;

-- UPDATE/DELETE (linha). Em tabela particionada, o trigger de linha e
-- clonado automaticamente para as particoes existentes e futuras.
DROP TRIGGER IF EXISTS trg_audit_log_immutable ON audit_log.audit_log_entry;
CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON audit_log.audit_log_entry
    FOR EACH ROW EXECUTE FUNCTION audit_log.reject_mutation();

-- TRUNCATE (statement). Triggers de statement NAO sao clonados para as
-- particoes, entao e preciso cria-los na tabela pai e em cada particao.
DROP TRIGGER IF EXISTS trg_audit_log_no_truncate ON audit_log.audit_log_entry;
CREATE TRIGGER trg_audit_log_no_truncate
    BEFORE TRUNCATE ON audit_log.audit_log_entry
    FOR EACH STATEMENT EXECUTE FUNCTION audit_log.reject_mutation();

DROP TRIGGER IF EXISTS trg_audit_log_no_truncate ON audit_log.audit_log_entry_2026_10;
CREATE TRIGGER trg_audit_log_no_truncate
    BEFORE TRUNCATE ON audit_log.audit_log_entry_2026_10
    FOR EACH STATEMENT EXECUTE FUNCTION audit_log.reject_mutation();

DROP TRIGGER IF EXISTS trg_audit_log_no_truncate ON audit_log.audit_log_entry_default;
CREATE TRIGGER trg_audit_log_no_truncate
    BEFORE TRUNCATE ON audit_log.audit_log_entry_default
    FOR EACH STATEMENT EXECUTE FUNCTION audit_log.reject_mutation();

-- ---------------------------------------------------------------------
-- Solicitacoes de trituracao (shred)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_log.shred_request (
                                                       shred_request_id           UUID PRIMARY KEY,
                                                       applicant_id               UUID NOT NULL,
                                                       requested_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at               TIMESTAMPTZ,
    anonymized_metric_bucket   VARCHAR(50)  -- ex: "2026-Q3", preserva metrica sem PII
    );