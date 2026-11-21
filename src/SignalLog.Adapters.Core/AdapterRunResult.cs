namespace SignalLog.Adapters.Core;

/// <summary>Result of one adapter run.</summary>
/// <param name="Published">Number of events handed to the publisher.</param>
/// <param name="TraceId">W3C trace id shared by every event of the run.</param>
public sealed record AdapterRunResult(int Published, string TraceId);
