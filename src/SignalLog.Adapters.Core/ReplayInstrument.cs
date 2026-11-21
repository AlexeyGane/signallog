namespace SignalLog.Adapters.Core;

/// <summary>One instrument of the replay source and the band its synthetic price moves in.</summary>
public sealed record ReplayInstrument
{
    /// <summary>Instrument id (ADR 0014), for example <c>NDEX.TFM.2026-12</c>.</summary>
    public required string InstrumentId { get; init; }

    /// <summary>Centre of the band, in <see cref="Currency"/> per <see cref="Unit"/>.</summary>
    public required decimal BasePrice { get; init; }

    /// <summary>ISO 4217 code.</summary>
    public required string Currency { get; init; }

    /// <summary>Quantity unit, for example MWh or bbl.</summary>
    public required string Unit { get; init; }

    /// <summary>Minimum price step; every price is a multiple of it.</summary>
    public required decimal TickSize { get; init; }

    /// <summary>Half-width of the band as a fraction of <see cref="BasePrice"/>; 0.05 means ±5 %.</summary>
    public required double Range { get; init; }
}
