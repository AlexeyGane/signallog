using System.Net;
using System.Text.Json;

using Microsoft.Extensions.Time.Testing;

using SignalLog.Adapters.Core;
using SignalLog.Contracts;

namespace SignalLog.Adapters.Tests;

// The publisher posts each event in CloudEvents structured mode to /v1/ticks (ADR 0010).
public sealed class HttpTickPublisherTests
{
    private static readonly Uri Endpoint = new("https://gateway.example/v1/ticks");
    private const string TraceParent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

    [Fact]
    public async Task Posts_each_event_as_structured_cloudevents_json()
    {
        using RecordingHandler handler = new(HttpStatusCode.Accepted);
        using HttpClient client = new(handler);
        IReadOnlyList<CloudEvent<PriceTickData>> events = await NewEventsAsync();

        await new HttpTickPublisher(client, Endpoint).PublishAsync(events, TestContext.Current.CancellationToken);

        Assert.Equal(events.Count, handler.Requests.Count);
        for (int i = 0; i < events.Count; i++)
        {
            RecordedRequest request = handler.Requests[i];
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal(Endpoint, request.Uri);
            Assert.Equal(HttpTickPublisher.MediaType, request.MediaType);
            Assert.Equal(events[i], JsonSerializer.Deserialize<CloudEvent<PriceTickData>>(request.Body, ContractJson.Options));
        }
    }

    [Fact]
    public async Task A_rejected_event_throws()
    {
        using RecordingHandler handler = new(HttpStatusCode.BadRequest);
        using HttpClient client = new(handler);
        IReadOnlyList<CloudEvent<PriceTickData>> events = await NewEventsAsync();

        _ = await Assert.ThrowsAsync<HttpRequestException>(() => new HttpTickPublisher(client, Endpoint).PublishAsync(events, TestContext.Current.CancellationToken));
        Assert.Single(handler.Requests);
    }

    [Fact]
    public void A_relative_endpoint_is_refused()
    {
        using HttpClient client = new();

        _ = Assert.Throws<ArgumentException>(() => new HttpTickPublisher(client, new Uri("/v1/ticks", UriKind.Relative)));
    }

    private static async Task<IReadOnlyList<CloudEvent<PriceTickData>>> NewEventsAsync()
    {
        FakeTimeProvider time = new(new DateTimeOffset(2026, 11, 11, 9, 15, 2, 123, TimeSpan.Zero));
        IReadOnlyList<PriceTickData> ticks = await new ReplaySource(new ReplayOptions(), time).GetTicksAsync(TestContext.Current.CancellationToken);
        return [.. ticks.Select(t => PriceTickEvents.Create(t, "/adapters/replay", TraceParent, time))];
    }

    private sealed record RecordedRequest(HttpMethod Method, Uri? Uri, string? MediaType, string Body);

    private sealed class RecordingHandler(HttpStatusCode status) : HttpMessageHandler
    {
        public List<RecordedRequest> Requests { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            string body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken);
            Requests.Add(new RecordedRequest(request.Method, request.RequestUri, request.Content?.Headers.ContentType?.MediaType, body));
            return new HttpResponseMessage(status);
        }
    }
}
