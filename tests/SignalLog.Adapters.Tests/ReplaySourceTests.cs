using Microsoft.Extensions.Time.Testing;

using SignalLog.Adapters.Core;
using SignalLog.Contracts;

namespace SignalLog.Adapters.Tests;

// The replay source is a pure function of seed, instrument and time (ADR 0011): reproducible, bounded, on the tick grid.
public sealed class ReplaySourceTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 11, 9, 15, 2, 123, TimeSpan.Zero);
    private static readonly ReplayOptions Options = new();

    [Fact]
    public async Task Same_seed_and_time_give_the_same_ticks_in_another_instance()
    {
        IReadOnlyList<PriceTickData> first = await new ReplaySource(Options, new FakeTimeProvider(Now)).GetTicksAsync(TestContext.Current.CancellationToken);
        IReadOnlyList<PriceTickData> second = await new ReplaySource(new ReplayOptions(), new FakeTimeProvider(Now)).GetTicksAsync(TestContext.Current.CancellationToken);

        Assert.Equal(first, second);
    }

    [Fact]
    public void Another_seed_gives_other_prices()
    {
        ReplayInstrument ttf = Options.Instruments[0];
        int differences = 0;
        for (int minute = 0; minute < 60; minute++)
        {
            DateTimeOffset time = Now.AddMinutes(minute);
            if (ReplaySource.PriceAt(ttf, 1, time) != ReplaySource.PriceAt(ttf, 2, time))
            {
                differences++;
            }
        }

        Assert.True(differences > 50, $"{differences} of 60 minutes differ");
    }

    [Fact]
    public void Prices_stay_in_the_band_on_the_tick_grid_and_move_between_runs()
    {
        foreach (ReplayInstrument instrument in Options.Instruments)
        {
            decimal low = instrument.BasePrice * (decimal)(1.0 - instrument.Range);
            decimal high = instrument.BasePrice * (decimal)(1.0 + instrument.Range);
            HashSet<decimal> distinct = [];
            // three days, one run per minute
            for (int minute = 0; minute < 3 * 24 * 60; minute++)
            {
                decimal price = ReplaySource.PriceAt(instrument, Options.Seed, Now.AddMinutes(minute));
                Assert.InRange(price, low - instrument.TickSize, high + instrument.TickSize);
                Assert.Equal(0m, price % instrument.TickSize);
                _ = distinct.Add(price);
            }

            Assert.True(distinct.Count > 200, $"{instrument.InstrumentId}: only {distinct.Count} distinct prices in three days");
        }
    }

    [Fact]
    public void Consecutive_minutes_move_by_small_steps()
    {
        foreach (ReplayInstrument instrument in Options.Instruments)
        {
            decimal limit = instrument.BasePrice * (decimal)instrument.Range * 0.1m;
            for (int minute = 0; minute < 24 * 60; minute++)
            {
                decimal step = Math.Abs(ReplaySource.PriceAt(instrument, Options.Seed, Now.AddMinutes(minute + 1)) - ReplaySource.PriceAt(instrument, Options.Seed, Now.AddMinutes(minute)));
                Assert.True(step <= limit, $"{instrument.InstrumentId}: a step of {step} within one minute");
            }
        }
    }

    [Fact]
    public async Task Ticks_are_replay_last_prices_of_every_instrument_at_the_current_millisecond()
    {
        DateTimeOffset withSubMilliseconds = Now.AddTicks(4567);

        IReadOnlyList<PriceTickData> ticks = await new ReplaySource(Options, new FakeTimeProvider(withSubMilliseconds)).GetTicksAsync(TestContext.Current.CancellationToken);

        Assert.Equal(Options.Instruments.Select(static i => i.InstrumentId), ticks.Select(static t => t.InstrumentId));
        Assert.All(ticks, static t =>
        {
            Assert.Equal(SourceKind.Replay, t.SourceKind);
            Assert.Equal(PriceType.Last, t.PriceType);
            Assert.Equal(Now, t.EventTimeUtc);
        });
        Assert.Equal("EUR", ticks[0].Currency);
        Assert.Equal("bbl", ticks[1].Unit);
    }

    [Fact]
    public async Task Default_instruments_are_valid_instrument_ids()
    {
        IReadOnlyList<PriceTickData> ticks = await new ReplaySource(Options, new FakeTimeProvider(Now)).GetTicksAsync(TestContext.Current.CancellationToken);

        Assert.All(ticks, static t => Assert.True(Identifiers.IsInstrumentId(t.InstrumentId), t.InstrumentId));
    }
}
