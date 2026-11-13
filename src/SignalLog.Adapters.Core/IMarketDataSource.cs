using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;

/// <summary>The single abstraction over price sources; every venue adapter implements it (ADR 0011).</summary>
public interface IMarketDataSource
{
    /// <summary>
    /// Adapter id: the last segment of the CloudEvents <c>source</c> (<c>/adapters/{AdapterId}</c>) and the
    /// <c>adapterId</c> of control commands (ADR 0013). Lower case, digits and single hyphens.
    /// </summary>
    string AdapterId { get; }

    /// <summary>The ticks available now, at most one per instrument.</summary>
    ValueTask<IReadOnlyList<PriceTickData>> GetTicksAsync(CancellationToken cancellationToken);
}
