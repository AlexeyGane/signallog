namespace SignalLog.Contracts;

/// <summary>Where a price comes from (BR-PRICE-03). Serialized as LIVE, REPLAY.</summary>
public enum SourceKind
{
    /// <summary>A licensed live source.</summary>
    Live,

    /// <summary>The replay generator.</summary>
    Replay,
}
