CREATE SCHEMA vault_data;
CREATE SCHEMA audit_log;


CREATE TABLE vault_data.encryption_key_reference (
                                                     key_reference_id     UUID PRIMARY KEY,
                                                     kek_key_id           VARCHAR(255) NOT NULL,
                                                     encrypted_dek_blob   BYTEA NOT NULL,
                                                     issued_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
                                                     is_revoked           BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE vault_data.vault_record (
                                         applicant_id               UUID PRIMARY KEY,
                                         sin_ciphertext             BYTEA NOT NULL,
                                         full_address_ciphertext     BYTEA,
                                         key_reference_id           UUID NOT NULL REFERENCES vault_data.encryption_key_reference(key_reference_id),
                                         created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
                                         is_shredded                BOOLEAN NOT NULL DEFAULT false
);


CREATE INDEX idx_vault_record_active ON vault_data.vault_record(applicant_id)
    WHERE is_shredded = false;

CREATE TABLE audit_log.audit_log_entry (
                                           audit_id             UUID PRIMARY KEY,
                                           applicant_id         UUID NOT NULL,
                                           operation_type       VARCHAR(30) NOT NULL,
                                           requesting_service   VARCHAR(100) NOT NULL,
                                           occurred_at          TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (occurred_at);


CREATE TABLE audit_log.audit_log_entry_2026_09 PARTITION OF audit_log.audit_log_entry
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

CREATE INDEX idx_audit_log_applicant_id ON audit_log.audit_log_entry(applicant_id);


REVOKE UPDATE, DELETE ON audit_log.audit_log_entry FROM PUBLIC;

CREATE OR REPLACE FUNCTION audit_log.reject_mutation() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_log_entry e append-only: UPDATE/DELETE nao permitidos (Loi 25 compliance)';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON audit_log.audit_log_entry
    FOR EACH ROW EXECUTE FUNCTION audit_log.reject_mutation();

CREATE TABLE audit_log.shred_request (
                                         shred_request_id           UUID PRIMARY KEY,
                                         applicant_id               UUID NOT NULL,
                                         requested_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
                                         completed_at               TIMESTAMPTZ,
                                         anonymized_metric_bucket   VARCHAR(50)
);