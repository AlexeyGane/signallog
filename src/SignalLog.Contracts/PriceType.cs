namespace SignalLog.Contracts;

/// <summary>Kind of price a tick carries (glossary: price type). Serialized as LAST, SETTLE, BID, ASK.</summary>
public enum PriceType
{
    /// <summary>Last trade.</summary>
    Last,

    /// <summary>Official settlement price.</summary>
    Settle,

    /// <summary>Best bid.</summary>
    Bid,

    /// <summary>Best offer.</summary>
    Ask,
}
