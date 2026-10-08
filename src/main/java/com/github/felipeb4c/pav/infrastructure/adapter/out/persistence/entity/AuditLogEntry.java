package com.github.felipeb4c.pav.infrastructure.adapter.out.persistence.entity;

import com.github.felipeb4c.pav.domain.enums.OperationType;
import jakarta.persistence.*;
import lombok.Getter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Getter
@Table(name = "audit_log_entry", schema = "audit_log")
public class AuditLogEntry {

    @EmbeddedId
    private AuditLogId id;

    @Column(name = "applicant_id", nullable = false)
    private UUID applicantId;

    @Enumerated(EnumType.STRING)
    @Column(name = "operation_type", nullable = false, length = 30)
    private OperationType operationType;

    @Column(name = "requesting_service", nullable = false, length = 100)
    private String requestingService;

    protected AuditLogEntry() {
    }

    private AuditLogEntry(AuditLogId id, UUID applicantId, OperationType operationType, String requestingService) {
        this.id = id;
        this.applicantId = applicantId;
        this.operationType = operationType;
        this.requestingService = requestingService;
    }

    public static AuditLogEntry create(UUID applicantId, OperationType operationType, String requestingService) {
        return new AuditLogEntry(
                new AuditLogId(UUID.randomUUID(), Instant.now()),
                applicantId,
                operationType,
                requestingService
        );
    }
}
