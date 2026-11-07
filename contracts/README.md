# Contracts

Message schemas shared by producers and consumers ([ADR 0012](../docs/adr/0012-message-contract-and-versioning.md)).

| Event type | Schema | Samples | .NET types |
|---|---|---|---|
| `signallog.price.tick.v1` | [`schemas/price-tick/v1.json`](schemas/price-tick/v1.json) | [`samples/price-tick/v1/`](samples/price-tick/v1/) | `SignalLog.Contracts`: `CloudEvent<PriceTickData>`, `PriceTickEvents.Create`, `ContractJson.Options` |

- Each schema (JSON Schema 2020-12) describes the whole CloudEvents 1.0 envelope in JSON structured mode together with its `data`. Its `$id` is the raw GitHub URL of the file on `main`; producers send it as `dataschema`.
- Unknown attributes and data fields are allowed: additive changes keep the version, and consumers ignore what they do not know. A breaking change gets a new version: a new `type`, a new schema file and new samples next to the old ones.
- Samples named `valid-*.json` must validate; the contract tests in `tests/SignalLog.Contracts.Tests` check every sample, every message the producer helper writes, and a set of invalid messages that must fail, in CI.
- Wire rules enforced by `ContractJson.Options`: data fields in camelCase, enums as upper-case strings (`LAST`, `REPLAY`), prices as JSON numbers from `decimal`, timestamps in UTC with a trailing `Z` and millisecond precision.
- Reference data (`reference/instruments.json` and others in [the domain model](../docs/domain/model.md#reference-data-stored-changed-through-pull-requests)) will live here too.
