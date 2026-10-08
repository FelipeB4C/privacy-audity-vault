package com.github.felipeb4c.pav.infrastructure.adapter.out.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class AuditLogId implements Serializable {

    private static final long serialVersionUID = 1L;

    @Column(name = "audit_id", nullable = false)
    private UUID auditId;

    @Column(name = "occurred_at", nullable = false, updatable = false)
    private Instant occurredAt;

    protected AuditLogId() {}

    public AuditLogId(UUID auditId, Instant occurredAt) {
        this.auditId = auditId;
        this.occurredAt = occurredAt;
    }

    public UUID getAuditId() {
        return auditId;
    }

    public Instant getOccurredAt() {
        return occurredAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        AuditLogId that = (AuditLogId) o;
        return Objects.equals(auditId, that.auditId) &&
                Objects.equals(occurredAt, that.occurredAt);
    }

    @Override
    public int hashCode() {
        return Objects.hash(auditId, occurredAt);
    }
}