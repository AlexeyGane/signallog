# Requirements

This folder holds SignalLog's quality requirements and business rules. Functional scope lives in Azure Boards (Epics, Features, User Stories, [ADR 0003](../adr/0003-application-lifecycle-management.md)); decisions live in the [ADRs](../adr/README.md); domain knowledge lives in the [domain pages](../domain/README.md).

| Page | What it covers |
|---|---|
| [Non-functional requirements](nfr.md) | The NFR catalogue: every `NFR-*` identifier referenced by an ADR, with a measurable target and a verification method |
| [Business rules](business-rules.md) | The domain rules (`BR-*`): how energy is counted, which contract a price belongs to, when data counts as stale; each with an example and the ADR that decided it |

## How NFRs are written

- **Identifier:** `NFR-<AREA>-<NN>`. The identifier never changes once an ADR references it; a retired NFR keeps its number with status `Retired`.
- **Areas:** `COST`, `PERF`, `SEC`, `REL` (reliability), `OPS` (operability), `MNT` (maintainability), `DATA`, `LEGAL`, `GOV` (governance), `DOC`, `DEMO`, `DEL` (delivery). Each maps to an [ISO/IEC 25010](https://www.iso.org/standard/78176.html) quality characteristic or an [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/) pillar, given in the catalogue.
- **Scenario first:** each NFR states a [quality-attribute scenario](../standards/concepts-and-sources.md#quality-attribute-scenario) (stimulus, environment, expected response) before its target, so that the target can be tested.
- **Measurable target:** a number with a unit and a percentile where it applies, or a binary rule that a check can evaluate.
- **Verification:** how the target is proven — a unit or integration test, a CI check, an alert, a periodic review — and when.
- **Traceability:** each NFR lists the ADRs that address it; each ADR lists the NFRs in its *Traces to* field. Features in Azure Boards reference NFRs by identifier.

## How business rules are written

- **Identifier:** `BR-<AREA>-<NN>`, stable once referenced, like NFR identifiers.
- **Areas:** `TIME` (time and delivery), `INST` (instruments and delivery periods), `PRICE`, `FRESH` (freshness and market status), `SRC` (data sources).
- **Content:** the rule in one or two sentences a domain expert can check, an example with real dates or values, the ADR that decided it, how it is verified, and a status.
- **Boundary with NFRs:** a business rule is true of the domain in any implementation; an NFR is a quality of this system. An NFR may exist to verify a rule (NFR-DATA-05 verifies BR-TIME-01).
- **Status:** the values below; `Reference` additionally marks a rule recorded for a domain that is out of scope.

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
