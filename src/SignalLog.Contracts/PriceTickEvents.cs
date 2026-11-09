namespace SignalLog.Contracts;

/// <summary>Creates <c>signallog.price.tick.v1</c> events (ADR 0012).</summary>
public static class PriceTickEvents
{
    /// <summary>CloudEvents <c>type</c> of version 1.</summary>
    public const string EventType = "signallog.price.tick.v1";

    /// <summary>The schema's <c>$id</c>, sent as the CloudEvents <c>dataschema</c>.</summary>
    public const string SchemaId = "https://raw.githubusercontent.com/AlexeyGane/signallog/main/contracts/schemas/price-tick/v1.json";

    /// <summary>
    /// Wraps a tick in its envelope with a new UUIDv7 id; <c>time</c> is the id's timestamp, so the two agree to
    /// the millisecond.
    /// </summary>
    /// <param name="data">The tick; <see cref="PriceTickData.InstrumentId"/> must be a valid instrument id.</param>
    /// <param name="source">The adapter, for example <c>/adapters/replay</c>.</param>
    /// <param name="traceParent">W3C trace context of the producing operation.</param>
    /// <param name="timeProvider">Clock for the id and <c>time</c>.</param>
    public static CloudEvent<PriceTickData> Create(PriceTickData data, string source, string traceParent, TimeProvider timeProvider)
    {
        ArgumentNullException.ThrowIfNull(data);
        ArgumentNullException.ThrowIfNull(timeProvider);
        if (!Identifiers.IsAdapterSource(source))
        {
            throw new ArgumentException($"'{source}' is not an adapter source such as /adapters/replay.", nameof(source));
        }

        if (!Identifiers.IsInstrumentId(data.InstrumentId))
        {
            throw new ArgumentException($"'{data.InstrumentId}' is not an instrument id (ADR 0014).", nameof(data));
        }

        if (!Identifiers.IsTraceParent(traceParent))
        {
            throw new ArgumentException($"'{traceParent}' is not a W3C traceparent.", nameof(traceParent));
        }

        Guid id = EventIds.New(timeProvider);
        return new CloudEvent<PriceTickData>
        {
            Id = EventIds.ToCanonicalString(id),
            Source = source,
            Type = EventType,
            Time = EventIds.GetTimestamp(id),
            DataSchema = SchemaId,
            TraceParent = traceParent,
            Data = data,
        };
    }
}
