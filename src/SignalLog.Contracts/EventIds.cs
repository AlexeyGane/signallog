namespace SignalLog.Contracts;

/// <summary>
/// Event identifiers: UUID version 7, transported and stored as the canonical lowercase string (ADR 0012).
/// </summary>
public static class EventIds
{
    /// <summary>Creates a time-ordered event id from the given clock.</summary>
    public static Guid New(TimeProvider timeProvider)
    {
        ArgumentNullException.ThrowIfNull(timeProvider);
        return Guid.CreateVersion7(timeProvider.GetUtcNow());
    }

    /// <summary>Canonical wire form: lowercase, hyphenated, no braces.</summary>
    public static string ToCanonicalString(Guid id)
    {
        return id.ToString("D");
    }

    /// <summary>Reads the Unix-millisecond timestamp from the first 48 bits in RFC 9562 byte order.</summary>
    public static DateTimeOffset GetTimestamp(Guid id)
    {
        if (id.Version != 7)
        {
            throw new ArgumentException($"Expected a UUID version 7, got version {id.Version}.", nameof(id));
        }

        Span<byte> bytes = stackalloc byte[16];
        _ = id.TryWriteBytes(bytes, bigEndian: true, out _);

        long unixMilliseconds = 0;
        for (int i = 0; i < 6; i++)
        {
            unixMilliseconds = (unixMilliseconds << 8) | bytes[i];
        }

        return DateTimeOffset.FromUnixTimeMilliseconds(unixMilliseconds);
    }
}
