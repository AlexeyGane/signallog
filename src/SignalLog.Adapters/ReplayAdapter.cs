using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

using SignalLog.Adapters.Core;

namespace SignalLog.Adapters;

/// <summary>
/// The replay adapter (ADR 0011): one synthetic last price per configured instrument as a
/// <c>signallog.price.tick.v1</c> event, on the schedule from the app setting <c>ReplayAdapterSchedule</c>. The
/// function name has no hyphen, so it can be disabled through the app setting
/// <c>AzureWebJobs.ReplayAdapter.Disabled</c> on Linux (ADR 0013).
/// </summary>
public sealed class ReplayAdapter
{
    /// <summary>
    /// App setting with the NCRONTAB schedule (six fields, seconds first), for example <c>0 */1 * * * *</c> for
    /// second 0 of every minute. Set by IaC, locally in local.settings.json. A flat name, one per adapter function
    /// (<c>{FunctionName}Schedule</c>), so the same name works as an environment variable on Linux and on Windows.
    /// Without it the host reports, when it indexes the function, that the expression does not resolve to a value.
    /// </summary>
    public const string ScheduleSetting = nameof(ReplayAdapter) + "Schedule";

    // The Functions host replaces %name% with the value of that app setting (binding expression)
    private const string Schedule = "%" + ScheduleSetting + "%";

    private static readonly Action<ILogger, int, string, Exception?> LogRun = LoggerMessage.Define<int, string>(
        LogLevel.Information,
        new EventId(1, "ReplayRun"),
        "Replay adapter published {Count} price ticks in trace {TraceId}");

    private readonly AdapterRunner _runner;
    private readonly ILogger<ReplayAdapter> _logger;

    /// <summary>Created by the Functions host for each invocation.</summary>
    public ReplayAdapter(ReplaySource source, ITickPublisher publisher, TimeProvider timeProvider, ILogger<ReplayAdapter> logger)
    {
        _runner = new AdapterRunner(source, publisher, timeProvider);
        _logger = logger;
    }

    /// <summary>Runs on the schedule of <see cref="ScheduleSetting"/>; the demo works around the clock (ADR 0011, D2).</summary>
    [Function(nameof(ReplayAdapter))]
    public async Task RunAsync([TimerTrigger(Schedule)] TimerInfo timer, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(timer);

        AdapterRunResult result = await _runner.RunAsync(cancellationToken).ConfigureAwait(false);
        LogRun(_logger, result.Published, result.TraceId, null);
    }
}
