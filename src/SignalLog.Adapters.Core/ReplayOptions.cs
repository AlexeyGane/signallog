namespace SignalLog.Adapters.Core;

/// <summary>Settings of the replay source (ADR 0011).</summary>
public sealed class ReplayOptions
{
    /// <summary>Seed of the generator; the same seed gives the same prices at the same time.</summary>
    public long Seed { get; init; } = 20261111;

    /// <summary>
    /// Instruments to replay. Until the reference data story the defaults name current front months with levels and
    /// bands near the market of November 2026 (Brent about 91 USD/bbl after daily moves of 5–8 %, TTF about
    /// 82–90 EUR/MWh after a weekly fall of 17.7 %).
    /// </summary>
    public IReadOnlyList<ReplayInstrument> Instruments { get; init; } =
    [
        new ReplayInstrument { InstrumentId = "NDEX.TFM.2026-12", BasePrice = 85.000m, Currency = "EUR", Unit = "MWh", TickSize = 0.005m, Range = 0.08 },
        new ReplayInstrument { InstrumentId = "IFEU.BRN.2027-01", BasePrice = 91.00m, Currency = "USD", Unit = "bbl", TickSize = 0.01m, Range = 0.06 },
    ];
}
