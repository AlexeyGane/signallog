namespace SignalLog.Fitness.BannedApiProbe;

internal static class Probe
{
    internal static void Identifiers()
    {
        _ = Guid.NewGuid(); // BANNED ADR 0012
        _ = Guid.Empty.ToByteArray(); // BANNED ADR 0012
        _ = Guid.Empty.ToByteArray(bigEndian: true);
        _ = Guid.CreateVersion7();
    }

    internal static void Time()
    {
        _ = DateTime.Now; // BANNED ADR 0017
        _ = DateTime.UtcNow; // BANNED ADR 0017
        _ = DateTime.Today; // BANNED ADR 0017
        _ = DateTimeOffset.Now; // BANNED ADR 0017
        _ = DateTimeOffset.UtcNow; // BANNED ADR 0017
        _ = TimeProvider.System.GetUtcNow();
    }
}
