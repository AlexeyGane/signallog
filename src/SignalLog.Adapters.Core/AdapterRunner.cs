using System.Diagnostics;

using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;

/// <summary>Result of one adapter run.</summary>
/// <param name="Published">Number of events handed to the publisher.</param>
/// <param name="TraceId">W3C trace id shared by every event of the run.</param>
public sealed record AdapterRunResult(int Published, string TraceId);

/// <summary>
/// One run of an adapter: reads the ticks of its source, wraps each in a <c>signallog.price.tick.v1</c> event and
/// publishes them. Every event of a run carries the run's <c>traceparent</c>, so one trace follows the run from the
/// adapter through ingestion (ADR 0007, ADR 0012).
/// </summary>
public sealed class AdapterRunner
{
    /// <summary>Activity source of the adapters, for OpenTelemetry (ADR 0007).</summary>
    public static readonly ActivitySource ActivitySource = new("SignalLog.Adapters");

    private readonly IMarketDataSource _source;
    private readonly ITickPublisher _publisher;
    private readonly TimeProvider _timeProvider;

    /// <summary>Creates a runner for one source.</summary>
    public AdapterRunner(IMarketDataSource source, ITickPublisher publisher, TimeProvider timeProvider)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(publisher);
        ArgumentNullException.ThrowIfNull(timeProvider);

        _source = source;
        _publisher = publisher;
        _timeProvider = timeProvider;
    }

    /// <summary>Runs once: read, wrap, publish.</summary>
    public async Task<AdapterRunResult> RunAsync(CancellationToken cancellationToken)
    {
        // Without a listener StartActivity returns null; a plain Activity still gives the run a W3C trace context,
        // joined to the ambient one (the function invocation) when there is one.
        using Activity activity = ActivitySource.StartActivity("AdapterRun") ?? new Activity("AdapterRun").Start();
        _ = activity.SetTag("signallog.adapter", _source.AdapterId);

        string traceParent = activity.Id ?? throw new InvalidOperationException("The adapter run has no trace context.");
        string source = "/adapters/" + _source.AdapterId;

        IReadOnlyList<PriceTickData> ticks = await _source.GetTicksAsync(cancellationToken).ConfigureAwait(false);
        List<CloudEvent<PriceTickData>> events = new(ticks.Count);
        foreach (PriceTickData tick in ticks)
        {
            events.Add(PriceTickEvents.Create(tick, source, traceParent, _timeProvider));
        }

        await _publisher.PublishAsync(events, cancellationToken).ConfigureAwait(false);
        _ = activity.SetTag("signallog.published", events.Count);
        return new AdapterRunResult(events.Count, activity.TraceId.ToHexString());
    }
}
