using System.Text.Json;
using System.Text.Json.Nodes;

using Json.Schema;

using Microsoft.Extensions.Time.Testing;

namespace SignalLog.Contracts.Tests;

// Confirmation criteria of ADR 0012 for signallog.price.tick.v1: what a producer writes validates against the
// schema in contracts/, a consumer reads v1 samples including unknown fields, and invalid messages are rejected.
public sealed class PriceTickContractTests
{
    private const string TraceParent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";
    private static readonly DateTimeOffset Now = new(2026, 11, 7, 9, 15, 2, 123, TimeSpan.Zero);
    private static readonly JsonSchema Schema = LoadSchema();

    private static readonly PriceTickData Tick = new()
    {
        InstrumentId = "NDEX.TFM.2026-12",
        Price = 38.415m,
        Currency = "EUR",
        Unit = "MWh",
        PriceType = PriceType.Last,
        EventTimeUtc = new DateTimeOffset(2026, 11, 7, 9, 15, 2, 0, TimeSpan.Zero),
        SourceKind = SourceKind.Replay,
    };

    [Fact]
    public void Schema_id_is_the_dataschema_producers_send()
    {
        using JsonDocument schema = JsonDocument.Parse(File.ReadAllText(ContractsPath("schemas/price-tick/v1.json")));

        Assert.Equal(PriceTickEvents.SchemaId, schema.RootElement.GetProperty("$id").GetString());
    }

    [Fact]
    public void Produced_event_validates_against_the_schema()
    {
        string json = Serialize(PriceTickEvents.Create(Tick, "/adapters/replay", TraceParent, new FakeTimeProvider(Now)));

        Assert.True(IsValid(json), json);
    }

    [Fact]
    public void Produced_event_has_a_uuidv7_id_matching_its_time()
    {
        CloudEvent<PriceTickData> created = PriceTickEvents.Create(Tick, "/adapters/replay", TraceParent, new FakeTimeProvider(Now));

        Guid id = Guid.Parse(created.Id);
        Assert.Equal(7, id.Version);
        Assert.Equal(EventIds.ToCanonicalString(id), created.Id);
        Assert.Equal(Now, created.Time);
        Assert.Equal(EventIds.GetTimestamp(id), created.Time);
        Assert.Equal(PriceTickEvents.EventType, created.Type);
        Assert.Equal(PriceTickEvents.SchemaId, created.DataSchema);
    }

    [Fact]
    public void Wire_form_keeps_decimal_precision_upper_case_enums_and_utc_z()
    {
        string json = Serialize(PriceTickEvents.Create(Tick, "/adapters/replay", TraceParent, new FakeTimeProvider(Now)));
        JsonNode data = JsonNode.Parse(json)!["data"]!;

        Assert.Equal("38.415", data["price"]!.ToJsonString());
        Assert.Equal("LAST", data["priceType"]!.GetValue<string>());
        Assert.Equal("REPLAY", data["sourceKind"]!.GetValue<string>());
        Assert.Equal("2026-11-07T09:15:02.000Z", data["eventTimeUtc"]!.GetValue<string>());
        Assert.Equal("2026-11-07T09:15:02.123Z", JsonNode.Parse(json)!["time"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("valid-ttf-last.json")]
    [InlineData("valid-unknown-fields.json")]
    public void Samples_validate_against_the_schema(string sample)
    {
        Assert.True(IsValid(ReadSample(sample)), sample);
    }

    [Fact]
    public void Consumer_reads_a_sample_with_unknown_fields()
    {
        CloudEvent<PriceTickData>? read = JsonSerializer.Deserialize<CloudEvent<PriceTickData>>(ReadSample("valid-unknown-fields.json"), ContractJson.Options);

        Assert.NotNull(read);
        Assert.Equal("IFEU.BRN.2027-01", read.Data.InstrumentId);
        Assert.Equal(64.37m, read.Data.Price);
        Assert.Equal(PriceType.Settle, read.Data.PriceType);
        Assert.Equal(new DateTimeOffset(2026, 11, 6, 19, 30, 0, TimeSpan.Zero), read.Data.EventTimeUtc);
    }

    [Fact]
    public void Round_trip_returns_the_same_event()
    {
        CloudEvent<PriceTickData> created = PriceTickEvents.Create(Tick, "/adapters/replay", TraceParent, new FakeTimeProvider(Now));

        CloudEvent<PriceTickData>? read = JsonSerializer.Deserialize<CloudEvent<PriceTickData>>(Serialize(created), ContractJson.Options);

        Assert.Equal(created, read);
    }

    [Theory]
    [InlineData("id", "\"3f2504e0-4f89-41d3-9a0c-0305e82c3301\"")]
    [InlineData("time", "\"2026-11-07T09:15:02.123+00:00\"")]
    [InlineData("type", "\"signallog.price.tick.v2\"")]
    [InlineData("source", "\"adapters/replay\"")]
    [InlineData("dataschema", "\"https://signallog.example/schemas/price-tick/v1.json\"")]
    [InlineData("traceparent", null)]
    [InlineData("data.instrumentId", "\"NDEX.TFM.2026-13\"")]
    [InlineData("data.instrumentId", "\"NDEX.TFM.M+1\"")]
    [InlineData("data.price", "\"38.415\"")]
    [InlineData("data.currency", "\"eur\"")]
    [InlineData("data.priceType", "\"MID\"")]
    [InlineData("data.sourceKind", "\"SIMULATED\"")]
    [InlineData("data.eventTimeUtc", null)]
    public void Invalid_messages_fail_schema_validation(string path, string? value)
    {
        Assert.False(IsValid(Mutate(ReadSample("valid-ttf-last.json"), path, value)));
    }

    [Theory]
    [InlineData("data.price", "\"38.415\"")]
    [InlineData("data.eventTimeUtc", "\"2026-11-07T10:15:02+01:00\"")]
    [InlineData("data.priceType", "\"MID\"")]
    [InlineData("traceparent", null)]
    public void Consumer_rejects_invalid_messages(string path, string? value)
    {
        string json = Mutate(ReadSample("valid-ttf-last.json"), path, value);

        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<CloudEvent<PriceTickData>>(json, ContractJson.Options));
    }

    [Fact]
    public void Producer_refuses_invalid_instrument_source_and_traceparent()
    {
        FakeTimeProvider time = new(Now);

        Assert.Throws<ArgumentException>(() => PriceTickEvents.Create(Tick with { InstrumentId = "TTF M+1" }, "/adapters/replay", TraceParent, time));
        Assert.Throws<ArgumentException>(() => PriceTickEvents.Create(Tick, "replay", TraceParent, time));
        Assert.Throws<ArgumentException>(() => PriceTickEvents.Create(Tick, "/adapters/replay", "00-00000000000000000000000000000000-00f067aa0ba902b7-01", time));
    }

    [Fact]
    public void Writer_refuses_a_non_utc_timestamp()
    {
        CloudEvent<PriceTickData> created = PriceTickEvents.Create(Tick, "/adapters/replay", TraceParent, new FakeTimeProvider(Now));
        CloudEvent<PriceTickData> local = created with { Data = Tick with { EventTimeUtc = new DateTimeOffset(2026, 11, 7, 10, 15, 2, TimeSpan.FromHours(1)) } };

        Assert.Throws<JsonException>(() => Serialize(local));
    }

    [Theory]
    [InlineData("NDEX.TFM.2026-12")]
    [InlineData("IFEU.BRN.2027-01")]
    [InlineData("XEEE.G0BM.2026-12")]
    [InlineData("NDEX.TFM.2026-11-09")]
    [InlineData("NDEX.TFM.2026-11-07-WE")]
    [InlineData("NDEX.TFM.2026-11-04-BOW")]
    [InlineData("NDEX.TFM.2026-W46")]
    [InlineData("NDEX.TFM.2026-W46-WD")]
    [InlineData("NDEX.TFM.2026-11-04-BOM")]
    [InlineData("NDEX.TFM.2027-Q1")]
    [InlineData("NDEX.TFM.2027-SUM")]
    [InlineData("NDEX.TFM.2026-WIN")]
    [InlineData("NDEX.TFM.2026-GY")]
    [InlineData("NDEX.TFM.2027")]
    public void Every_period_kind_of_adr_0014_is_an_instrument_id(string id)
    {
        Assert.True(Identifiers.IsInstrumentId(id));
    }

    [Theory]
    [InlineData("NDEX.TFM.2026.12")]
    [InlineData("NDEX.TFM.M+1")]
    [InlineData("ndex.TFM.2026-12")]
    [InlineData("NDEX.TFM.2026-13")]
    [InlineData("NDEX.TFM.2026-W54")]
    [InlineData("NDEX.TFM")]
    [InlineData("NDEX.TFM.2026-12\n")]
    [InlineData("NDEX.TFM.２０２６-12")]
    public void Malformed_instrument_ids_are_rejected(string id)
    {
        Assert.False(Identifiers.IsInstrumentId(id));
    }

    private static bool IsValid(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        return Schema.Evaluate(document.RootElement).IsValid;
    }

    private static string Serialize(CloudEvent<PriceTickData> value)
    {
        return JsonSerializer.Serialize(value, ContractJson.Options);
    }

    private static string ReadSample(string name)
    {
        return File.ReadAllText(ContractsPath("samples/price-tick/v1/" + name));
    }

    // Replaces (or with a null value removes) one property, addressed as "name" or "data.name"
    private static string Mutate(string json, string path, string? value)
    {
        JsonObject root = JsonNode.Parse(json)!.AsObject();
        string[] parts = path.Split('.');
        JsonObject parent = parts.Length == 1 ? root : root[parts[0]]!.AsObject();
        string name = parts[^1];
        if (value is null)
        {
            Assert.True(parent.Remove(name), path);
        }
        else
        {
            parent[name] = JsonNode.Parse(value);
        }

        return root.ToJsonString();
    }

    // contracts/ is copied next to the test assembly (see the project file)
    private static string ContractsPath(string relativePath)
    {
        return Path.Combine(AppContext.BaseDirectory, "contracts", relativePath);
    }

    private static JsonSchema LoadSchema()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(ContractsPath("schemas/price-tick/v1.json")));
        return JsonSchema.Build(document.RootElement.Clone(), new BuildOptions { SchemaRegistry = new() });
    }
}
