using System.Text.RegularExpressions;

namespace SignalLog.Contracts;

/// <summary>
/// Format checks shared with the JSON Schema: the instrument id (ADR 0014), the adapter source and the W3C
/// <c>traceparent</c>.
/// [0-9] is used instead of \d, which in .NET also matches non-ASCII digits, and \z instead of $, which in .NET
/// also matches before a trailing newline.
/// </summary>
public static partial class Identifiers
{
    /// <summary>True for <c>{venueMic}.{productCode}.{deliveryPeriodId}</c> with a period kind from ADR 0014.</summary>
    public static bool IsInstrumentId(string? value)
    {
        return value is not null && InstrumentIdPattern().IsMatch(value);
    }

    /// <summary>True for an adapter source such as <c>/adapters/replay</c> or <c>/adapters/ice-endex</c>.</summary>
    public static bool IsAdapterSource(string? value)
    {
        return value is not null && AdapterSourcePattern().IsMatch(value);
    }

    /// <summary>True for a version-00 <c>traceparent</c> whose trace id and parent id are not all zeros.</summary>
    public static bool IsTraceParent(string? value)
    {
        if (value is null || !TraceParentPattern().IsMatch(value))
        {
            return false;
        }

        // "00-" + trace id (32 hex) + "-" + parent id (16 hex) + "-" + flags; all-zero ids are invalid (W3C)
        return value.AsSpan(3, 32).ContainsAnyExcept('0') && value.AsSpan(36, 16).ContainsAnyExcept('0');
    }

    [GeneratedRegex(@"^[A-Z0-9]{4}\.[A-Z0-9]{1,12}\.[0-9]{4}(-(0[1-9]|1[0-2])(-(0[1-9]|[12][0-9]|3[01])(-(WE|BOW|BOM))?)?|-W(0[1-9]|[1-4][0-9]|5[0-3])(-WD)?|-Q[1-4]|-(SUM|WIN|GY))?\z", RegexOptions.CultureInvariant)]
    private static partial Regex InstrumentIdPattern();

    [GeneratedRegex(@"^/adapters/[a-z0-9]+(-[a-z0-9]+)*\z", RegexOptions.CultureInvariant)]
    private static partial Regex AdapterSourcePattern();

    [GeneratedRegex(@"^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}\z", RegexOptions.CultureInvariant)]
    private static partial Regex TraceParentPattern();
}
