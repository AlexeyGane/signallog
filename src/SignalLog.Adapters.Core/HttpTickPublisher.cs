using System.Text;
using System.Text.Json;

using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;

/// <summary>
/// Posts each event in CloudEvents structured mode to the ingress endpoint behind API Management, <c>/v1/ticks</c>
/// (ADR 0010). Authentication with the managed identity is added together with the gateway.
/// </summary>
public sealed class HttpTickPublisher : ITickPublisher
{
    /// <summary>Media type of one event in structured mode (CloudEvents JSON format).</summary>
    public const string MediaType = "application/cloudevents+json";

    private readonly HttpClient _httpClient;
    private readonly Uri _endpoint;

    /// <summary>Creates the publisher for an absolute endpoint URL.</summary>
    public HttpTickPublisher(HttpClient httpClient, Uri endpoint)
    {
        ArgumentNullException.ThrowIfNull(httpClient);
        ArgumentNullException.ThrowIfNull(endpoint);

        if (!endpoint.IsAbsoluteUri)
        {
            throw new ArgumentException($"The ingress endpoint must be an absolute URL, got '{endpoint}'.", nameof(endpoint));
        }

        _httpClient = httpClient;
        _endpoint = endpoint;
    }

    /// <inheritdoc />
    public async Task PublishAsync(IReadOnlyList<CloudEvent<PriceTickData>> events, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(events);

        foreach (CloudEvent<PriceTickData> tick in events)
        {
            using StringContent content = new(JsonSerializer.Serialize(tick, ContractJson.Options), Encoding.UTF8, MediaType);
            using HttpResponseMessage response = await _httpClient.PostAsync(_endpoint, content, cancellationToken).ConfigureAwait(false);
            _ = response.EnsureSuccessStatusCode();
        }
    }
}
