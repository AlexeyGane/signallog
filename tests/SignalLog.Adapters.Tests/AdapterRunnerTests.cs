using System.Diagnostics;
using System.Text.Json;

using Json.Schema;

using Microsoft.Extensions.Time.Testing;

using SignalLog.Adapters.Core;
using SignalLog.Contracts;

namespace SignalLog.Adapters.Tests;

// One run of the replay adapter: one event per instrument, valid against the v1 schema, all in the run's trace.
public sealed class AdapterRunnerTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 11, 9, 15, 2, 123, TimeSpan.Zero);
    private static readonly JsonSchema Schema = LoadSchema();

    [Fact]
    public async Task Publishes_one_event_per_instrument_that_validates_against_the_v1_schema()
    {
        RecordingPublisher publisher = new();

        AdapterRunResult result = await NewRunner(publisher).RunAsync(TestContext.Current.CancellationToken);

        Assert.Equal(2, result.Published);
        Assert.Equal(2, publisher.Events.Count);
        foreach (CloudEvent<PriceTickData> tick in publisher.Events)
        {
            string json = JsonSerializer.Serialize(tick, ContractJson.Options);
            using JsonDocument document = JsonDocument.Parse(json);
            Assert.True(Schema.Evaluate(document.RootElement).IsValid, json);
        }
    }

    [Fact]
    public async Task Events_carry_the_run_trace_unique_uuidv7_ids_and_the_replay_source()
    {
        RecordingPublisher publisher = new();

        AdapterRunResult result = await NewRunner(publisher).RunAsync(TestContext.Current.CancellationToken);

        Assert.Matches("^[0-9a-f]{32}$", result.TraceId);
        Assert.All(publisher.Events, e =>
        {
            Assert.Equal("/adapters/replay", e.Source);
            Assert.Equal(PriceTickEvents.EventType, e.Type);
            Assert.Equal(result.TraceId, e.TraceParent.Substring(3, 32));
            Assert.Equal(7, Guid.Parse(e.Id).Version);
        });
        Assert.Single(publisher.Events.Select(static e => e.TraceParent).Distinct());
        Assert.Equal(publisher.Events.Count, publisher.Events.Select(static e => e.Id).Distinct().Count());
    }

    [Fact]
    public async Task A_run_joins_the_ambient_trace_of_the_invocation()
    {
        using Activity invocation = new Activity("invocation").Start();
        RecordingPublisher publisher = new();

        AdapterRunResult result = await NewRunner(publisher).RunAsync(TestContext.Current.CancellationToken);

        Assert.Equal(invocation.TraceId.ToHexString(), result.TraceId);
    }

    [Fact]
    public async Task Two_runs_have_different_traces()
    {
        AdapterRunResult first = await NewRunner(new RecordingPublisher()).RunAsync(TestContext.Current.CancellationToken);
        AdapterRunResult second = await NewRunner(new RecordingPublisher()).RunAsync(TestContext.Current.CancellationToken);

        Assert.NotEqual(first.TraceId, second.TraceId);
    }

    [Fact]
    public async Task A_publisher_failure_fails_the_run()
    {
        AdapterRunner runner = new(new ReplaySource(new ReplayOptions(), new FakeTimeProvider(Now)), new FailingPublisher(), new FakeTimeProvider(Now));

        _ = await Assert.ThrowsAsync<HttpRequestException>(() => runner.RunAsync(TestContext.Current.CancellationToken));
    }

    private static AdapterRunner NewRunner(ITickPublisher publisher)
    {
        FakeTimeProvider time = new(Now);
        return new AdapterRunner(new ReplaySource(new ReplayOptions(), time), publisher, time);
    }

    private static JsonSchema LoadSchema()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "contracts", "schemas", "price-tick", "v1.json");
        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(path));
        return JsonSchema.Build(document.RootElement.Clone(), new BuildOptions { SchemaRegistry = new() });
    }

    private sealed class RecordingPublisher : ITickPublisher
    {
        public List<CloudEvent<PriceTickData>> Events { get; } = [];

        public Task PublishAsync(IReadOnlyList<CloudEvent<PriceTickData>> events, CancellationToken cancellationToken)
        {
            Events.AddRange(events);
            return Task.CompletedTask;
        }
    }

    private sealed class FailingPublisher : ITickPublisher
    {
        public Task PublishAsync(IReadOnlyList<CloudEvent<PriceTickData>> events, CancellationToken cancellationToken)
        {
            throw new HttpRequestException("ingress unavailable");
        }
    }
}
