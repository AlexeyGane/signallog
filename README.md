# SignalLog

Cloud-native, event-driven commodity market data platform on Azure, built with .NET 10.

SignalLog ingests futures prices for crude oil, natural gas and LNG from ICE Futures Europe, ICE Endex and EEX through pluggable adapters, transports them over Azure Service Bus, stores them in Azure Cosmos DB and pushes live updates to a Blazor WebAssembly UI.

> The name is an anagram: **OIL + GAS + LNG → SIGNAL LOG**.

## Status

Solution skeleton. Decisions are recorded in [docs/adr](docs/adr/README.md).

## Architecture at a glance

```text
Adapters (Functions, timer) ─► API Management ─► Ingress (Functions, HTTP)
   ─► Service Bus topic price-ticks ─► Ingestion (Functions) ─► Cosmos DB
                                      └► live-push ─► SignalR ─► Blazor UI
```

## Repository layout

```text
src/
  SignalLog.Contracts       CloudEvents payloads and identifier rules (ADR 0012)
  SignalLog.Domain          Venue → Product → Contract, sessions, roll rules (ADR 0014, 0017)
  SignalLog.Observability   Shared OpenTelemetry setup (ADR 0007)
  SignalLog.Adapters        func-signallog-adapters  — timer-triggered adapters
  SignalLog.Ingress         func-signallog-ingress   — HTTP → Service Bus behind APIM
  SignalLog.Ingestion       func-signallog-ingestion — persist and live-push subscriptions
  SignalLog.Api             func-signallog-api       — Query and Admin API
  SignalLog.Web             Blazor WebAssembly UI
tests/
  SignalLog.Contracts.Tests
  Fitness/BannedApiProbe    must NOT compile; checked by eng/Test-BannedApi.ps1
```

## Build

Requires the .NET 10 SDK (version pinned in `global.json`).

```powershell
dotnet build SignalLog.slnx
dotnet test --solution SignalLog.slnx
dotnet format SignalLog.slnx --verify-no-changes
./eng/Test-BannedApi.ps1
```

Build rules applied to every project (`Directory.Build.props`): nullable reference types, warnings as errors, .NET analyzers at `latest-recommended`, code style enforced in build, NuGet audit of transitive packages, and banned APIs from `BannedSymbols.txt` reported as errors. Package versions are managed centrally in `Directory.Packages.props`.

## Documentation

- [Architecture Decision Records](docs/adr/README.md)
- [Branching and release standard](docs/standards/branching-and-release.md)

## License

[MIT](LICENSE)
