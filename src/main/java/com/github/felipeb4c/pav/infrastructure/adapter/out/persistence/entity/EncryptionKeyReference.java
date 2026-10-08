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
@Table(name = "encryption_key_reference", schema = "vault_data")
public class EncryptionKeyReference {

    @Id
    @Column(name = "key_reference_id", nullable = false)
    private UUID keyReferenceId;

    @Column(name = "kek_key_id", nullable = false, length = 255)
    private String kekKeyId;

    @Column(name = "encrypted_dek_blob", nullable = false)
    private byte[] encryptedDekBlob;

    @Column(name = "issued_at", nullable = false, updatable = false)
    private Instant issuedAt;

    @Column(name = "is_revoked", nullable = false)
    private Boolean isRevoked;

}
