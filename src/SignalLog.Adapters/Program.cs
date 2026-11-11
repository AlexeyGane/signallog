using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using SignalLog.Adapters.Core;

FunctionsApplicationBuilder builder = FunctionsApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton(new ReplayOptions());
builder.Services.AddSingleton<ReplaySource>();
builder.Services.AddSingleton<ITickPublisher>(static services =>
{
    // The ingress endpoint behind API Management (ADR 0010), for example https://<gateway>/v1/ticks. Set by IaC as
    // the app setting Ingress__Endpoint; read when the first run needs it, so the host starts without it.
    string endpoint = services.GetRequiredService<IConfiguration>()["Ingress:Endpoint"]
        ?? throw new InvalidOperationException("The app setting Ingress__Endpoint (the ingress URL ending in /v1/ticks) is not set.");

    // One long-lived client per process; the pooled connection lifetime lets it follow DNS changes
    HttpClient client = new(new SocketsHttpHandler { PooledConnectionLifetime = TimeSpan.FromMinutes(2) });
    return new HttpTickPublisher(client, new Uri(endpoint, UriKind.Absolute));
});

builder.Build().Run();
