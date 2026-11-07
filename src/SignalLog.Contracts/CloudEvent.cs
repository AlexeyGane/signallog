using System.Text.Json.Serialization;

namespace SignalLog.Contracts;

/// <summary>
/// CloudEvents 1.0 envelope in JSON structured mode with the distributed tracing extension (ADR 0012).
/// Unknown attributes are ignored when reading; a missing required attribute fails deserialization.
/// </summary>
/// <typeparam name="TData">Type of the event data.</typeparam>
public sealed record CloudEvent<TData>
{
    /// <summary>CloudEvents specification version.</summary>
    [JsonPropertyName("specversion")]
    public string SpecVersion { get; init; } = "1.0";

    /// <summary>UUID version 7 as its canonical lowercase string (ADR 0012).</summary>
    [JsonPropertyName("id")]
    public required string Id { get; init; }

    /// <summary>The producing adapter, for example <c>/adapters/replay</c>.</summary>
    [JsonPropertyName("source")]
    public required string Source { get; init; }

    /// <summary>Event type with its version, for example <c>signallog.price.tick.v1</c>.</summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }

    /// <summary>When the producer created the event, UTC.</summary>
    [JsonPropertyName("time")]
    public required DateTimeOffset Time { get; init; }

    /// <summary>Media type of <see cref="Data"/>.</summary>
    [JsonPropertyName("datacontenttype")]
    public string DataContentType { get; init; } = "application/json";

    /// <summary>The <c>$id</c> of the JSON Schema of <see cref="Data"/> and this envelope.</summary>
    [JsonPropertyName("dataschema")]
    public required string DataSchema { get; init; }

    /// <summary>W3C trace context of the producing operation.</summary>
    [JsonPropertyName("traceparent")]
    public required string TraceParent { get; init; }

    /// <summary>The event data.</summary>
    [JsonPropertyName("data")]
    public required TData Data { get; init; }
}
