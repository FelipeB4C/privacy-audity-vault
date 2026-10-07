# Privacy &amp; Audit Vault (PAV)

[\--Image of: --Java](https://www.google.com/url?sa=E&amp;q=https%3A%2F%2Fjdk.java.net%2F25%2F) [\--Image of: --Spring Boot](https://www.google.com/url?sa=E&amp;q=https%3A%2F%2Fspring.io%2Fprojects%2Fspring-boot) [\--Image of: --PostgreSQL](https://www.google.com/url?sa=E&amp;q=https%3A%2F%2Fwww.postgresql.org%2F) [\--Image of: --AWS KMS](https://www.google.com/url?sa=E&amp;q=https%3A%2F%2Flocalstack.cloud%2F) [\--Image of: --Compliance](https://www.google.com/url?sa=E&amp;q=https%3A%2F%2Fwww.quebec.ca%2Fgouvernement%2Ftravailler-gouvernement%2Ftravailler-fonction-publique%2Fservices-aux-citoyens%2Fprotection-renseignements-personnels)

&gt; **Cofre centralizado de PII (Personally Identifiable Information) e motor de auditoria imutável projetado para conformidade com a Loi 25 de Quebec (Canadá).**

---

## 📌 Visão Geral

O **Privacy &amp; Audit Vault (PAV)** é um microsserviço de plataforma agnóstico de domínio desenvolvido para resolver os desafios regulatórios impostos pela **Loi 25** de Quebec em instituições financeiras e fintechs.

Em vez de permitir que múltiplos serviços de negócio (como sistemas de originação de empréstimos — LOS — ou motores de cálculo hipotecário — MSTE) implementem suas próprias soluções de criptografia e auditoria, o PAV centraliza o armazenamento, consulta e destruição de dados pessoais sensíveis (ex: **SIN - Social Insurance Number** e endereço completo).

### Principais Pilares da Solução

1. **Envelope Encryption (AES-256-GCM + AWS KMS):** Criptografia por campo antes de qualquer escrita no banco de dados. As chaves de dados (*DEK*) são envelopadas por uma chave mestra (*KEK*) mantida no **AWS KMS** na região canadense `ca-central-1` (Montreal). Para execução e testes locais sem custos de nuvem, o serviço utiliza o **LocalStack**.
2. **Auditoria Imutável e Assíncrona:** Interceptação declarativa de acessos a PII via Spring AOP (`@Auditable`). Os logs são gravados no esquema `audit_log` do PostgreSQL com permissões de `UPDATE` e `DELETE` revogadas e *triggers* de imutabilidade.
3. **Direito ao Esquecimento via Crypto-Shredding:** Cumprimento do *Right to be Forgotten* em tempo constante $O(1)$. A destruição ou revogação da DEK torna os bytes armazenados residualmente em disco ou backups em lixo matemático irrecuperável.

---

## 📐 Arquitetura

O projeto adota **Hexagonal Architecture (Ports and Adapters)**, mantendo a regra de negócio totalmente desacoplada de frameworks, drivers JDBC e SDKs de nuvem.

### Visão de Containers (C4 Level 2)

```
C4Container
    title Diagrama de Container - Privacy and Audit Vault (PAV)

    Person(client, "Serviço Cliente (ex: MSTE / LOS)", "Consome operações de PII e auditoria")

    System_Boundary(pav_boundary, "Privacy and Audit Vault") {
        Container(api, "Vault API", "Spring Boot 4 / Java 25", "Expõe endpoints REST para PII e direito ao esquecimento")
        Container(domain, "Vault Domain Core", "Java 25 (Hexagonal Core)", "Orquestra operações sem acoplamento a infraestrutura")
        Container(aop, "Audit Aspect", "Spring AOP", "Intercepta leituras e dispara eventos de auditoria")
        Container(asyncaudit, "Audit Event Listener", "Spring Async / Virtual Threads", "Persiste auditoria no banco de forma assíncrona")
        Container(crypto, "Encryption Converter", "AES-256-GCM + AWS KMS SDK v2", "Executa envelope encryption de campos PII")
        ContainerDb(vaultdb, "Vault Data Store", "PostgreSQL 16 (schema vault_data)", "Persiste PII criptografado e referências de chave")
        ContainerDb(auditdb, "Audit Log Store", "PostgreSQL 16 (schema audit_log)", "Tabela append-only e particionada de auditoria")
    }

    System_Ext(kms, "AWS KMS / LocalStack (ca-central-1)", "Gerencia KEK e operações GenerateDataKey/Decrypt")

    Rel(client, api, "Lê, grava ou solicita esquecimento", "HTTPS/JSON")
    Rel(api, domain, "Delega requisição")
    Rel(domain, aop, "Método interceptado")
    Rel(aop, asyncaudit, "Publica AuditEvent pós-commit")
    Rel(asyncaudit, auditdb, "Persiste registro", "JDBC (async)")
    Rel(domain, crypto, "Criptografa/decripta campos")
    Rel(crypto, kms, "GenerateDataKey / Decrypt", "AWS SDK v2")
    Rel(domain, vaultdb, "Lê/grava dados cifrados", "JDBC")

```

---

## 🛠️ Tech Stack

| Camada                 | Tecnologia                                | Propósito                                                                    |
| ---------------------- | ----------------------------------------- | ---------------------------------------------------------------------------- |
| **Linguagem**          | Java 25 (LTS)                             | Virtual Threads (Loom) para alta concorrência em I/O e eventos de auditoria. |
| **Framework**          | Spring Boot 4.x                           | Spring Data JPA, Spring AOP e Spring Security / Actuator.                    |
| **Criptografia &amp; KMS** | AWS SDK v2 (`software.amazon.awssdk:kms`) | Envelope Encryption na região `ca-central-1` (Montreal).                     |
| **Ambiente Local**     | LocalStack                                | Emulação local do AWS KMS via Docker.                                        |
| **Banco de Dados**     | PostgreSQL 16                             | Schemas isolados (`vault_data` e `audit_log` com particionamento mensal).    |
| **Migrations**         | Flyway                                    | Versionamento imutável de DDL e triggers de auditoria.                       |
| **Métricas**           | Micrometer + Prometheus                   | Observabilidade de métricas operacionais sem exposição de PII.               |
| **Testes**             | Testcontainers                            | Testes de integração automatizados subindo PostgreSQL e LocalStack reais.    |

---

## 🚀 Como Executar Localmente

### Pré-requisitos

* **Linux / macOS / WSL2** (Base Debian/Ubuntu recomendado)
* **Java 25** instalado
* **Docker &amp; Docker Compose**

### 1\. Clocar o repositório

```
git clone https://github.com/seu-usuario/privacy-audit-vault.git
cd privacy-audit-vault

```

### 2\. Subir a infraestrutura (PostgreSQL + LocalStack AWS KMS)

```
docker compose up -d

```

### 3\. Executar a aplicação Spring Boot

```
./mvnw spring-boot:run

```

---

## 🔌 API Endpoints Principais

### 1\. Armazenar PII Criptografado

* **POST** `/api/v1/vault/{applicantId}`
* **Payload:**

```
{
  "sin": "046-454-286",
  "fullAddress": "1234 Rue Sainte-Catherine, Montreal, QC H3B 1A7"
}

```

* **Response:** `201 Created`

### 2\. Recuperar PII (com Auditoria Automática)

* **GET** `/api/v1/vault/{applicantId}`
* **Response:** `200 OK`

```
{
  "applicantId": "3f1a9c2e-7b4d-4e9a-9c11-6a2f0e8d1234",
  "sin": "046-454-286",
  "fullAddress": "1234 Rue Sainte-Catherine, Montreal, QC H3B 1A7",
  "createdAt": "2026-08-02T10:15:00Z"
}

```

### 3\. Exercer Direito ao Esquecimento (Crypto-Shredding)

* **POST** `/api/v1/vault/{applicantId}/forget`
* **Response:** `202 Accepted`

```
{
  "shredRequestId": "9a7c1e3f-2b4d-4e6a-8c10-3f5a7b9d1e2c",
  "applicantId": "3f1a9c2e-7b4d-4e9a-9c11-6a2f0e8d1234",
  "status": "COMPLETED",
  "completedAt": "2026-09-15T14:40:22Z"
}

```

---

## 📜 Licença

Este projeto está sob a licença MIT. Sinta-se à vontade para utilizá-lo e adaptá-lo para seu portfólio e estudos.