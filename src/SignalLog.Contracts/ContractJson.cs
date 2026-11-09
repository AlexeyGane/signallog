using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace SignalLog.Contracts;

/// <summary>
/// The one set of JSON serializer options for contract messages: camelCase data fields, enums as upper-case
/// strings (LAST, REPLAY), decimals as JSON numbers, timestamps as UTC with a trailing Z (ADR 0012, ADR 0017).
/// </summary>
public static class ContractJson
{
    /// <summary>Read-only options shared by producers and consumers.</summary>
    public static JsonSerializerOptions Options { get; } = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        // MakeReadOnly needs an explicit resolver; reflection-based, as everywhere else in the solution
        JsonSerializerOptions options = new(JsonSerializerDefaults.Web)
        {
            NumberHandling = JsonNumberHandling.Strict,
            TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
        };
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseUpper, allowIntegerValues: false));
        options.Converters.Add(new UtcTimestampConverter());
        options.MakeReadOnly();
        return options;
    }
}

/// <summary>
/// Writes a <see cref="DateTimeOffset"/> as <c>yyyy-MM-ddTHH:mm:ss.fffZ</c> and refuses a non-UTC offset;
/// reads only timestamps that end in Z (ADR 0017).
/// </summary>
public sealed class UtcTimestampConverter : JsonConverter<DateTimeOffset>
{
    private const string WireFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'";

    /// <inheritdoc />
    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        string? text = reader.GetString();
        if (text is null || !text.EndsWith('Z'))
        {
            // A JSON null and an empty string read differently: "got null" and "got ''"
            string got = text is null ? "null" : $"'{text}'";
            throw new JsonException($"Timestamps are UTC with a trailing Z (ADR 0017), got {got}.");
        }

        return DateTimeOffset.Parse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options)
    {
        ArgumentNullException.ThrowIfNull(writer);
        if (value.Offset != TimeSpan.Zero)
        {
            throw new JsonException($"Timestamps are written in UTC (ADR 0017), got offset {value.Offset}.");
        }

        writer.WriteStringValue(value.ToString(WireFormat, CultureInfo.InvariantCulture));
    }
}
