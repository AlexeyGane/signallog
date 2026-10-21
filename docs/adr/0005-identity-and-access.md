# 0005 — Identity and access model

| Field | Value |
|---|---|
| Status | Proposed (revision of original ADR-005, Accepted) |
| Date | 2026-10-18 |
| Deciders | Solution Architect, Key Developer *(one person, see README)* |
| Supersedes | ADR-005 (original one-line version) |
| Related | [0004](0004-ci-cd-platform.md), [0006](0006-compute-hosting.md), [0010](0010-api-management-ingestion-gateway.md), [0015](0015-ui-and-real-time-push.md) |
| Traces to | NFR-SEC-01 (no static secrets), NFR-SEC-02 (least privilege), C4 L2 all containers |

## Context and Problem Statement

The original ADR selected Entra ID, OAuth 2.0 client credentials, RBAC and Key Vault. Client credentials with a client secret made sense when ingestion adapters ran outside Azure. All workloads now run in Azure, so every service-to-service call can use a managed identity: the token flow is still OAuth 2.0, but there is no secret to store, rotate or leak. How do humans, workloads and pipelines authenticate and get authorized?

## Decision Drivers

- D1 — No static secrets for workload-to-workload or pipeline-to-cloud access.
- D2 — Least privilege, scoped to individual resources.
- D3 — Role-based authorization in the UI (viewer vs admin).
- D4 — Demonstrable OAuth 2.0 usage with Entra ID.

## Considered Options

1. Managed identities + Entra ID app roles + workload identity federation for CI
2. Client credentials with client secrets stored in Key Vault
3. Shared keys / connection strings (SAS)

## Decision Outcome

**Chosen option:** Option 1.

### Model

| Principal | Authenticates to | Mechanism | Authorization |
|---|---|---|---|
| Adapter Function app | API Management | User-assigned managed identity obtains an Entra ID token for the SignalLog Ingestion API app registration (OAuth 2.0 client credentials flow, no secret) | App role `Prices.Publish`, validated by APIM policy ([0010](0010-api-management-ingestion-gateway.md)) |
| API Management | Ingress function | System-assigned managed identity (`authentication-managed-identity` policy) | Ingress function accepts only tokens issued to APIM's identity (App Service authentication) |
| Ingress function | Service Bus | Managed identity | `Azure Service Bus Data Sender` on the `price-ticks` topic |
| Ingestion Function | Service Bus, Cosmos DB | Managed identity | `Azure Service Bus Data Receiver` on its subscription; Cosmos DB built-in data contributor role scoped to the SignalLog database |
| Admin/Query API | Cosmos DB, Service Bus, ARM | Managed identity | Cosmos DB built-in data reader role (plus contributor on `adapter-status`); `Data Sender` on `adapter-commands`; custom role limited to updating app settings on adapter Function apps ([0013](0013-adapter-control-plane.md)) |
| Human users | UI and API | Entra ID sign-in (OIDC, authorization code + PKCE) | App roles `SignalLog.Viewer`, `SignalLog.Admin` |
| GitHub Actions | Azure Resource Manager | OIDC workload identity federation ([0004](0004-ci-cd-platform.md)) | Contributor on the environment's resource group only |

Key Vault remains for genuinely secret material that cannot be replaced by identity (for example, a third-party market data API key in [0011](0011-market-data-sourcing-and-licensing.md)). Access via Key Vault references and RBAC, not access policies.

### Consequences

- Good, because no secret exists that could appear in a log, a repository or a leaked config file.
- Good, because each permission is a reviewable role assignment in IaC.
- Bad, because local development needs a developer identity (`DefaultAzureCredential` via Azure CLI sign-in) and per-developer role assignments in the dev environment.

### Confirmation

- IaC sets `disableLocalAuth` on Service Bus and on the Cosmos DB account, so key-based access is impossible rather than merely unused.
- A threat model (STRIDE) for the ingestion path references this ADR.

## Pros and Cons of the Options

### Managed identities + federation
- Good, because it is secretless and least-privilege by construction.
- Bad, because it has a steeper initial setup and local-dev configuration.

### Client secrets in Key Vault
- Good, because it is simple and portable outside Azure.
- Bad, because secrets expire, must be rotated and can leak.

### SAS keys / connection strings
- Good, because it is the quickest to start.
- Bad, because shared keys carry broad rights and are not tied to an identity.
