using Microsoft.Extensions.Time.Testing;

namespace SignalLog.Contracts.Tests;

// Confirmation criteria of ADR 0012 for event identifiers.
public sealed class EventIdsTests
{
    private static readonly DateTimeOffset Start = new(2026, 10, 18, 9, 15, 2, 123, TimeSpan.Zero);

    [Fact]
    public void New_creates_rfc9562_version_7()
    {
        Guid id = EventIds.New(new FakeTimeProvider(Start));

        Assert.Equal(7, id.Version);
        Assert.InRange(id.Variant, 0b1000, 0b1011);
    }

    [Fact]
    public void Timestamp_round_trips_with_millisecond_precision()
    {
        Guid id = EventIds.New(new FakeTimeProvider(Start));

        Assert.Equal(Start, EventIds.GetTimestamp(id));
    }

    [Fact]
    public void Canonical_strings_sort_in_creation_order()
    {
        FakeTimeProvider time = new(Start);
        List<string> created = [];
        for (int i = 0; i < 100; i++)
        {
            created.Add(EventIds.ToCanonicalString(EventIds.New(time)));
            time.Advance(TimeSpan.FromMilliseconds(1));
        }

        List<string> sorted = created.Order(StringComparer.Ordinal).ToList();

        Assert.Equal(created, sorted);
    }

    [Fact]
    public void Canonical_string_is_lowercase_without_braces()
    {
        string text = EventIds.ToCanonicalString(EventIds.New(new FakeTimeProvider(Start)));

        Assert.Matches("^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", text);
    }

    [Fact]
    public void GetTimestamp_rejects_other_versions()
    {
        Guid version4 = Guid.Parse("3f2504e0-4f89-41d3-9a0c-0305e82c3301");

        Assert.Throws<ArgumentException>(() => EventIds.GetTimestamp(version4));
    }
}
