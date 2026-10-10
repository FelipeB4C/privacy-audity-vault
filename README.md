# Privacy & Audit Vault (PAV)

Serviço de plataforma para proteger informações pessoais identificáveis (PII), registrar acessos e atender ao direito ao esquecimento no contexto da Loi 25 de Quebec.

> **Fonte de verdade:** a especificação completa está em [`docs/PRIVACY AUDIT VAULT.md`](docs/PRIVACY%20AUDIT%20VAULT.md). Este README resume as decisões documentadas. A documentação descreve a arquitetura desejada; consulte o estado do código antes de assumir que todos os fluxos já estão implementados.

## Objetivos e arquitetura

O PAV centraliza operações sobre PII para que serviços clientes não precisem implementar sua própria criptografia ou trilha de auditoria. A arquitetura segue Ports and Adapters (hexagonal) e separa os dados em dois schemas PostgreSQL:

| Schema | Responsabilidade | Consistência |
| --- | --- | --- |
| `vault_data` | PII cifrada, referências de DEK e outbox transacional | Operações de gravação e shredding priorizam atomicidade |
| `audit_log` | Eventos de auditoria append-only, particionados por mês | Persistência assíncrona, com reprocessamento pelo outbox |

Os campos de PII são cifrados com AES-256-GCM usando envelope encryption: uma DEK cifra os dados e o AWS KMS protege a DEK com uma KEK. O LocalStack emula o KMS no desenvolvimento local, na região `ca-central-1`.

O evento de auditoria é gravado em `vault_data.audit_outbox` na mesma transação da operação de negócio. Um processador assíncrono grava o evento em `audit_log.audit_log_entry` e marca o outbox como processado; falhas são retentadas com backoff. O log de auditoria é protegido por permissões mínimas e triggers de imutabilidade.

No shredding, a aplicação revoga a referência da DEK e remove os ciphertexts na mesma transação que atualiza o registro, cria o `ShredRequest` e grava o evento de auditoria no outbox. A documentação ressalta que backups antigos, WAL e réplicas permanecem sujeitos à política de retenção; a KEK compartilhada não destrói automaticamente cópias históricas.

## Tecnologias

| Camada | Tecnologia |
| --- | --- |
| Runtime | Java 25 |
| Framework | Spring Boot 4.x, Spring Data JPA e Spring AOP |
| Banco | PostgreSQL 16 |
| Migrações | Flyway |
| Criptografia | AES-256-GCM, AWS KMS SDK v2 e LocalStack |
| Testes de integração | Testcontainers para PostgreSQL e LocalStack |
| Métricas | Micrometer e Prometheus, sem valores de PII |

## Executar localmente

### Pré-requisitos

- Java 25
- Docker e Docker Compose
- Uma conta LocalStack com acesso ao emulador AWS (plano AWS Freemium ou licença apropriada)

### 1. Clonar o projeto

```bash
git clone https://github.com/FelipeB4C/privacy-audity-vault.git privacy-audit-vault
cd privacy-audit-vault
```

### 2. Gerar o token de autenticação do LocalStack

O Compose usa a imagem `localstack/localstack:2026.9.1`, que exige `LOCALSTACK_AUTH_TOKEN`. **Não invente um valor:** o token é emitido pela sua conta LocalStack e ativa a licença associada.

1. Entre ou crie uma conta em [app.localstack.cloud](https://app.localstack.cloud/).
2. Abra a página **Auth Tokens** do workspace.
3. Gere ou copie seu **Personal Auth Token**. Confirme que a seção **Emulator Access** mostra uma licença para AWS (por exemplo, AWS Freemium). Se não houver licença atribuída, solicite ao administrador do workspace ou atribua uma licença disponível.
4. Na raiz do projeto, crie um arquivo chamado `.env` e adicione:

   ```dotenv
   LOCALSTACK_AUTH_TOKEN=cole_seu_token_completo_aqui
   ```

O `.env` está listado no `.gitignore`. Não cole o token em código, commits, issues, logs ou mensagens. Se ele for exposto, revogue-o/regenere-o na sua conta LocalStack.

### 3. Iniciar PostgreSQL e LocalStack

```bash
docker compose up -d
docker compose ps
```

Espere os serviços ficarem saudáveis. Confira a ativação do LocalStack e a disponibilidade do KMS:

```bash
curl -fsS http://localhost:4566/_localstack/info
curl -fsS http://localhost:4566/_localstack/health
```

O endpoint `/_localstack/info` deve indicar `"is_license_activated": true`; no health endpoint, o KMS deve estar disponível ou em execução. Se o container sair com código 55, verifique se o token está completo, válido e associado a uma licença ativa.

O PostgreSQL local é publicado em `localhost:5432`; o LocalStack em `localhost:4566`. As migrations Flyway são executadas pela aplicação. O Hibernate usa `ddl-auto: validate` para validar o mapeamento sem criar ou alterar o schema.

> Na configuração local do Compose, o PostgreSQL inicia com as credenciais de desenvolvimento definidas no próprio `docker-compose.yml`. Para ambientes compartilhados ou de produção, siga a especificação: use um papel restrito para a aplicação (`pav_app`) e mantenha a execução de migrations sob um papel separado, dono dos objetos.

### 4. Iniciar a aplicação

```bash
./gradlew bootRun
```

A aplicação local usa a porta `8081`. Para executar os testes existentes:

```bash
./gradlew test
```

## Contratos HTTP documentados

Os contratos abaixo refletem a especificação técnica. A especificação não define ainda um contrato HTTP para a operação de armazenamento de PII; não presuma uma rota ou payload até que ela seja formalizada.

### Consultar PII

```http
GET /api/v1/vault/{applicantId}
```

Retorna a PII descriptografada em memória e gera um evento `READ` para auditoria.

| Status | Significado |
| --- | --- |
| `200 OK` | Registro existe e não foi triturado |
| `404 Not Found` | `applicantId` não existe |
| `410 Gone` | Registro já foi triturado |
| `503 Service Unavailable` | Não foi possível garantir a consistência necessária |

### Exercer o direito ao esquecimento

```http
POST /api/v1/vault/{applicantId}/forget
```

Sem corpo de requisição. O shredding é síncrono e transacional.

| Status | Significado |
| --- | --- |
| `200 OK` | Shredding concluído |
| `404 Not Found` | `applicantId` não existe |
| `409 Conflict` | Registro já havia sido triturado |

## Segurança e operação

- Nunca registrar PII, plaintext de DEK ou token LocalStack em logs ou métricas.
- Manter a aplicação sem propriedade das tabelas; o papel `pav_app` recebe apenas os privilégios documentados. No `audit_log`, a aplicação deve ter somente `SELECT` e `INSERT`.
- Tratar o outbox como fonte de reprocessamento para falhas na gravação assíncrona da auditoria.
- Criar partições mensais de auditoria com antecedência; a partição `DEFAULT` é somente uma rede de segurança.
- Reter e proteger backups, WAL e réplicas segundo uma política compatível com o prazo de retenção de dados.

## Documentação

- [Especificação técnica, modelos de dados, DDL, diagramas, contratos e estratégia de segurança](docs/PRIVACY%20AUDIT%20VAULT.md)

## Licença

Este projeto está sob a licença MIT.
