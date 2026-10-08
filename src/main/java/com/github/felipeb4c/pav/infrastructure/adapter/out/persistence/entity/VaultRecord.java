package com.github.felipeb4c.pav.infrastructure.adapter.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Builder
@Getter
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PRIVATE)
@Table(name = "vault_record", schema = "vault_data")
public class VaultRecord {

    @Id
    @Column(name = "applicant_id", nullable = false)
    private UUID applicantId;

    @Column(name = "sin_ciphertext", nullable = false)
    private byte[] sinCiphertext;

    @Column(name = "full_address_ciphertext")
    private byte[] fullAddressCiphertext;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "key_reference_id", nullable = false)
    private EncryptionKeyReference encryptionKeyReference;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "is_shredded", nullable = false)
    private Boolean isShredded = false;

    @PrePersist
    private void onCreate(){
        this.createdAt = Instant.now();
    }

}
