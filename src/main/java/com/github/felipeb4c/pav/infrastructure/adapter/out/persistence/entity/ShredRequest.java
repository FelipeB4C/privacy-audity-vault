package com.github.felipeb4c.pav.infrastructure.adapter.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Builder
@Getter
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PRIVATE)
@Table(name = "shred_request", schema = "audit_log")
public class ShredRequest {

    @Id
    @Column(name = "shred_request_id", nullable = false)
    private UUID shredRequestId;

    @Column(name = "applicant_id", nullable = false)
    private UUID applicantId;

    @Column(name = "requested_at", nullable = false, updatable = false)
    private Instant requestedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "anonymized_metric_bucket", length = 50)
    private String anonymizedMetricBucket;

    @PrePersist
    private void onCreate(){
        this.requestedAt = Instant.now();
    }


}
