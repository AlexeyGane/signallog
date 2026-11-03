# Requirements

This folder holds SignalLog's quality requirements. Functional scope lives in Azure Boards (Epics, Features, User Stories, [ADR 0003](../adr/0003-application-lifecycle-management.md)); decisions live in the [ADRs](../adr/README.md); domain knowledge lives in the [domain pages](../domain/README.md).

| Page | What it covers |
|---|---|
| [Non-functional requirements](nfr.md) | The NFR catalogue: every `NFR-*` identifier referenced by an ADR, with a measurable target and a verification method |

## How NFRs are written

- **Identifier:** `NFR-<AREA>-<NN>`. The identifier never changes once an ADR references it; a retired NFR keeps its number with status `Retired`.
- **Areas:** `COST`, `PERF`, `SEC`, `REL` (reliability), `OPS` (operability), `MNT` (maintainability), `DATA`, `LEGAL`, `GOV` (governance), `DOC`, `DEMO`, `DEL` (delivery). Each maps to an ISO/IEC 25010 quality characteristic or an Azure Well-Architected Framework pillar, given in the catalogue.
- **Scenario first:** each NFR states a quality-attribute scenario (stimulus, environment, expected response) before its target, so that the target can be tested.
- **Measurable target:** a number with a unit and a percentile where it applies, or a binary rule that a check can evaluate.
- **Verification:** how the target is proven — a unit or integration test, a CI check, an alert, a periodic review — and when.
- **Traceability:** each NFR lists the ADRs that address it; each ADR lists the NFRs in its *Traces to* field. Features in Azure Boards reference NFRs by identifier.

## Status values

| Status | Meaning |
|---|---|
| Proposed | Target suggested; not yet agreed |
| Agreed | Target agreed; verification may not exist yet |
| Verified | Verification is automated or has been run and passed |
| Retired | No longer applies; identifier kept |

## Change rules

- An NFR target changes only through a pull request that also updates the ADRs whose *Traces to* field references it, if their reasoning depends on the old target.
- A new NFR identifier is added here before any ADR or work item references it.
