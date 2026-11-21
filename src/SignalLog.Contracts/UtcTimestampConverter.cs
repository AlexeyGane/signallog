using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SignalLog.Contracts;

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
