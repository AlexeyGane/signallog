# SignalLog

Cloud-native, event-driven commodity market data platform on Azure, built with .NET 10.

SignalLog ingests futures prices for crude oil, natural gas and LNG from ICE Futures Europe, ICE Endex and EEX through pluggable adapters, transports them over Azure Service Bus, stores them in Azure Cosmos DB and pushes live updates to a Blazor WebAssembly UI.

> The name is an anagram: **OIL + GAS + LNG → SIGNAL LOG**.

## Status

Architecture phase. Decisions are recorded in [docs/adr](docs/adr/README.md).

## Architecture at a glance

```text
Adapters (Functions, timer) ─► API Management ─► Ingress (Functions, HTTP)
   ─► Service Bus topic price-ticks ─► Ingestion (Functions) ─► Cosmos DB
                                      └► live-push ─► SignalR ─► Blazor UI
```

## Documentation

- [Architecture Decision Records](docs/adr/README.md)

## License

[MIT](LICENSE)
