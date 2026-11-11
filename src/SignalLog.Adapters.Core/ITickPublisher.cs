using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;

/// <summary>Hands price tick events to the ingestion path (ADR 0010).</summary>
public interface ITickPublisher
{
    /// <summary>Publishes the events; throws if any of them was not accepted.</summary>
    Task PublishAsync(IReadOnlyList<CloudEvent<PriceTickData>> events, CancellationToken cancellationToken);
}
