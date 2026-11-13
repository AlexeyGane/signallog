using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;

/// <summary>
/// The replay source (ADR 0011): synthetic last prices, marked <see cref="SourceKind.Replay"/>.
/// </summary>
/// <remarks>
/// The price is a pure function of seed, instrument and time, because a timer function keeps no state between runs:
/// two noise layers (hourly and daily knots) with cosine interpolation between them, so the price moves smoothly from
/// minute to minute and wanders within ±<see cref="ReplayInstrument.Range"/> of the base price. The random numbers
/// come from SplitMix64 over a FNV-1a hash of the instrument id, not from <see cref="Random"/> or
/// <see cref="string.GetHashCode()"/>: the sequence of <see cref="Random"/> for a seed and string hash codes are not
/// guaranteed to stay the same across .NET versions and processes.
/// </remarks>
public sealed class ReplaySource : IMarketDataSource
{
    private const double HourlyWeight = 0.6;
    private const double DailyWeight = 0.4;
    private const ulong DailySalt = 0xD1B54A32D192ED03UL;
    private static readonly DateTimeOffset Epoch = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly ReplayOptions _options;
    private readonly TimeProvider _timeProvider;

    /// <summary>Creates the source.</summary>
    public ReplaySource(ReplayOptions options, TimeProvider timeProvider)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(timeProvider);

        _options = options;
        _timeProvider = timeProvider;
    }

    /// <inheritdoc />
    public string AdapterId => "replay";

    /// <inheritdoc />
    public ValueTask<IReadOnlyList<PriceTickData>> GetTicksAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        DateTimeOffset now = _timeProvider.GetUtcNow();
        // The wire format carries milliseconds (ADR 0017)
        DateTimeOffset eventTime = new(now.Ticks - (now.Ticks % TimeSpan.TicksPerMillisecond), TimeSpan.Zero);
        List<PriceTickData> ticks = new(_options.Instruments.Count);
        foreach (ReplayInstrument instrument in _options.Instruments)
        {
            ticks.Add(new PriceTickData
            {
                InstrumentId = instrument.InstrumentId,
                Price = PriceAt(instrument, _options.Seed, eventTime),
                Currency = instrument.Currency,
                Unit = instrument.Unit,
                PriceType = PriceType.Last,
                EventTimeUtc = eventTime,
                SourceKind = SourceKind.Replay,
            });
        }

        return ValueTask.FromResult<IReadOnlyList<PriceTickData>>(ticks);
    }

    /// <summary>The synthetic price of an instrument at a time, rounded to its tick size.</summary>
    public static decimal PriceAt(ReplayInstrument instrument, long seed, DateTimeOffset time)
    {
        ArgumentNullException.ThrowIfNull(instrument);

        ulong key = SplitMix64(unchecked((ulong)seed) ^ Fnv1a(instrument.InstrumentId));
        double minutes = (time - Epoch).TotalMinutes;
        double noise = (HourlyWeight * Smooth(key, minutes / 60.0)) + (DailyWeight * Smooth(key ^ DailySalt, minutes / 1440.0));
        decimal price = instrument.BasePrice * (decimal)(1.0 + (instrument.Range * noise));
        return Math.Round(price / instrument.TickSize, MidpointRounding.ToEven) * instrument.TickSize;
    }

    // Value noise in [-1, 1]: random values at whole knots, cosine interpolation in between
    private static double Smooth(ulong key, double x)
    {
        double knot = Math.Floor(x);
        double fraction = x - knot;
        long k = (long)knot;
        double a = Uniform(key, k);
        double b = Uniform(key, k + 1);
        double weight = (1.0 - Math.Cos(Math.PI * fraction)) / 2.0;
        return a + ((b - a) * weight);
    }

    // A value in [-1, 1) determined by key and knot
    private static double Uniform(ulong key, long knot)
    {
        ulong bits = SplitMix64(key ^ unchecked((ulong)knot * 0x9E3779B97F4A7C15UL));
        return ((bits >> 11) * (1.0 / (1UL << 53)) * 2.0) - 1.0;
    }

    // SplitMix64 finalizer (Steele, Lea, Flood 2014)
    private static ulong SplitMix64(ulong value)
    {
        unchecked
        {
            ulong z = value + 0x9E3779B97F4A7C15UL;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
            return z ^ (z >> 31);
        }
    }

    // FNV-1a over the UTF-16 code units: stable across processes, unlike string.GetHashCode
    private static ulong Fnv1a(string text)
    {
        unchecked
        {
            ulong hash = 0xCBF29CE484222325UL;
            foreach (char c in text)
            {
                hash = (hash ^ c) * 0x100000001B3UL;
            }

            return hash;
        }
    }
}
