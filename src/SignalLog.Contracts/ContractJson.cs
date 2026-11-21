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
