namespace SignalLog.Contracts;

/// <summary>Kind of price a tick carries (glossary: price type). Serialized as LAST, SETTLE, BID, ASK.</summary>
public enum PriceType
{
    /// <summary>Last trade.</summary>
    Last,

    /// <summary>Official settlement price.</summary>
    Settle,

    /// <summary>Best bid.</summary>
    Bid,

    /// <summary>Best offer.</summary>
    Ask,
}

/// <summary>Where a price comes from (BR-PRICE-03). Serialized as LIVE, REPLAY.</summary>
public enum SourceKind
{
    /// <summary>A licensed live source.</summary>
    Live,

    /// <summary>The replay generator.</summary>
    Replay,
}

/// <summary>
/// The data of a <c>signallog.price.tick.v1</c> event (ADR 0012); schema: <c>contracts/schemas/price-tick/v1.json</c>.
/// </summary>
public sealed record PriceTickData
{
    /// <summary><c>{venueMic}.{productCode}.{deliveryPeriodId}</c> (ADR 0014), for example <c>NDEX.TFM.2026-12</c>.</summary>
    public required string InstrumentId { get; init; }

    /// <summary>Price in <see cref="Currency"/> per <see cref="Unit"/>; a decimal, never a double (ADR 0012).</summary>
    public required decimal Price { get; init; }

    /// <summary>ISO 4217 code, for example EUR.</summary>
    public required string Currency { get; init; }

    /// <summary>Quantity unit of the price, for example MWh.</summary>
    public required string Unit { get; init; }

    /// <summary>Kind of price.</summary>
    public required PriceType PriceType { get; init; }

    /// <summary>The venue's timestamp of the price, UTC (ADR 0017).</summary>
    public required DateTimeOffset EventTimeUtc { get; init; }

    /// <summary>Live or replay.</summary>
    public required SourceKind SourceKind { get; init; }
}
