# C# coding standard

| Field | Value |
|---|---|
| Status | Active |
| Owner | Solution Architect |
| Implements | [ADR 0004](../adr/0004-ci-cd-platform.md) (quality gates in CI), [ADR 0012](../adr/0012-message-contract-and-versioning.md) (identifiers, decimal prices, banned APIs), [ADR 0017](../adr/0017-time-and-timezones.md) (time), [ADR 0007](../adr/0007-observability.md) (logging and tracing) |
| Related | [Change workflow](change-workflow.md) (the solution check before every commit), [Documentation standard](documentation.md), [Concepts and their sources](concepts-and-sources.md) |

This standard records how C# is written in SignalLog and, for every rule, **what enforces it**. The rules come from three files in the repository root (`.editorconfig`, `Directory.Build.props`, `BannedSymbols.txt`) and from the code as it is; where the two differ, this page says which one wins. It changes through a normal pull request without a new ADR.

## 1. Who enforces what

A rule is enforced by one of three things. The difference matters: a rule that only the review enforces will be broken one day, and the review has to know which rules those are.

| Enforcer | What it is | What it catches |
|---|---|---|
| **Build** | `dotnet build` with `TreatWarningsAsErrors`, `AnalysisLevel` `latest-recommended`, `EnforceCodeStyleInBuild`, `Nullable` and the banned-API analyzer (`Directory.Build.props`) | Every compiler and analyzer diagnostic at warning or error severity: nullability, the recommended .NET code-quality rules (`CA*`), the code-style rules whose severity in `.editorconfig` is `warning` (`IDE*`), banned APIs (`RS0030`), the xUnit analyzers in test projects |
| **Format** | `dotnet format SignalLog.slnx --verify-no-changes` | Whitespace (indentation, braces on their own lines, trailing spaces, blank lines between `using` groups) and the order of `using` directives |
| **Review** | The owner reading the pull request, file by file ([change workflow, section 5](change-workflow.md#5-review-gate-a-resolved-thread-per-file)) | Everything else, including every `.editorconfig` preference at severity `silent` or `suggestion`: the editor may show it, nothing blocks it |

Both Build and Format run in the `build` job of `ci.yml`, which every pull request must pass, and on the owner's machine before every commit (`Invoke-SolutionCheck`). The *Enforced by* entries below were checked on 2026-11-15 with .NET SDK 10.0.402: each rule was broken on purpose in a probe file and the build or `dotnet format` was run; [Appendix A](#appendix-a-how-the-enforcement-was-checked) lists every probe and its result.

## 2. Layout

| Rule | Enforced by |
|---|---|
| Four spaces, no tabs; every brace on its own line (Allman style); a final newline; no trailing whitespace | Format |
| `using` directives outside the namespace, `System` first, groups separated by a blank line, sorted within a group | Format (order and blank lines); placement: review |
| One file-scoped namespace per file (`namespace SignalLog.Contracts;`), matching the folder | Review (`.editorconfig` suggestion; a block-scoped namespace builds and formats clean) |
| Braces on every `if`, `else`, `for`, `foreach` and `while` body, also for one statement | Review |
| Methods, constructors and local functions have block bodies; properties, accessors, indexers and lambdas are expression-bodied | Review |
| One public type per file, named like the file; a small type that exists only for the main type (a result record, for example) may share its file | Review |

```csharp
using System.Diagnostics;

using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;
```

## 3. Guard clauses

A public method or constructor checks its preconditions first and leaves early when they fail: the [guard clause](concepts-and-sources.md#guard-clause). The checks stand together at the top, and **one blank line** separates them from the rest of the body, so the reader sees at a glance where the preconditions end and the work begins.

| Rule | Enforced by |
|---|---|
| Reference parameters of public members are checked with `ArgumentNullException.ThrowIfNull`; other preconditions throw `ArgumentException` or `ArgumentOutOfRangeException` with `nameof(parameter)` and a message that says what was expected and what came | Review. The build does not check this: CA1062 ("Validate arguments of public methods"), the analyzer rule that would, is not part of the `latest-recommended` set we build with, and a public method that uses a parameter without checking it builds clean ([Appendix A](#appendix-a-how-the-enforcement-was-checked)) |
| A blank line after the last guard clause | Review (`dotnet format` neither adds nor requires it) |
| Inside a method, an early `return` or `continue` for a case that needs no work, instead of nesting the main path in an `if` | Review |

```csharp
public AdapterRunner(IMarketDataSource source, ITickPublisher publisher, TimeProvider timeProvider)
{
    ArgumentNullException.ThrowIfNull(source);
    ArgumentNullException.ThrowIfNull(publisher);
    ArgumentNullException.ThrowIfNull(timeProvider);

    _source = source;
    _publisher = publisher;
    _timeProvider = timeProvider;
}
```

## 4. Types and nullability

| Rule | Enforced by |
|---|---|
| Nullable reference types are on in every project; a nullability warning is an error | Build (`CS8602` and the other nullability diagnostics) |
| Explicit types everywhere: no `var`. The type on the left is the documentation of the line | Review (`.editorconfig` sets `var` to `false:silent`; `var` builds and formats clean) |
| `new()` without the type name when the type is already on the left: `List<CloudEvent<PriceTickData>> events = new(ticks.Count);` | Review |
| A return value that is ignored on purpose is discarded explicitly: `_ = activity.SetTag(...)` | Review |
| Language keywords for built-in types (`string`, `int`), not `String`, `Int32` | Review |
| No `this.` qualification | Review |

## 5. Naming

The `.editorconfig` naming rules are suggestions: the editor marks a wrong name, the build does not. One naming rule is enforced: the recommended analyzers forbid underscores in identifiers (CA1707), except in test projects, whose method names are sentences.

| Element | Style | Example |
|---|---|---|
| Namespaces, types, methods, properties, events, enum members, local functions | PascalCase | `AdapterRunner`, `RunAsync` |
| Interfaces | `I` + PascalCase | `ITickPublisher` |
| Type parameters | `T` + PascalCase | `TData` |
| Parameters and locals | camelCase | `cancellationToken`, `traceParent` |
| Private instance fields | `_` + camelCase | `_timeProvider` |
| Private static fields that are not read-only | `s_` + camelCase | (none in the code yet) |
| Constants and static read-only fields, public or private | PascalCase | `ScheduleSetting`, `HourlyWeight`, `LogRun` |
| Methods that return a task | `Async` suffix | `GetTicksAsync`, `PublishAsync` |

| Rule | Enforced by |
|---|---|
| The styles in the table | Review (editor suggestion) |
| No underscores in identifiers outside test projects | Build (`CA1707`; turned off for `tests/**` in `.editorconfig`) |
| `Async` suffix | Review |

## 6. Classes, records and members

| Rule | Enforced by |
|---|---|
| Classes are `sealed` unless they are designed for inheritance | Build for internal classes (`CA1852`); review for public classes |
| Data without behaviour is a `sealed record`; contract types use `required` `init` properties so that a missing field is a compile error | Review |
| A primary constructor when the class only stores its arguments (`RecordingHandler(HttpStatusCode status)` in the tests); an explicit constructor with guard clauses when it must check them | Review |
| Fields that are assigned only in the constructor are `readonly` | Build (`IDE0044`, severity `warning`) |
| A member that uses no instance state is `static` | Build (`CA1822`) |
| Local functions that capture nothing are `static` | Build (`IDE0062`, severity `warning`) |
| Lambdas that capture nothing are `static`: `Select(static e => e.Id)` | Review |
| Accessibility modifiers are always written | Review |

## 7. Numbers, text and culture

| Rule | Enforced by |
|---|---|
| Prices, money and quantities are `decimal`, never `double` or `float` (ADR 0012): binary floating point cannot represent most decimal prices exactly. `double` is for mathematics that is not money, such as the noise of the replay generator, and the result is converted to `decimal` before it is rounded to the tick size | Review (a `double` price builds clean); the contract tests check the serialized prices against the schema |
| Formatting and parsing name the culture: `CultureInfo.InvariantCulture` for anything a machine reads | Build (`CA1305`, `CA1304`, `CA1311`) |
| String comparisons name the comparison (`StringComparison.Ordinal` for identifiers), not `ToLower()` or `ToUpper()` | Build (`CA1862`, `CA1304`, `CA1311`) |

```csharp
decimal price = instrument.BasePrice * (decimal)(1.0 + (instrument.Range * noise));
return Math.Round(price / instrument.TickSize, MidpointRounding.ToEven) * instrument.TickSize;
```

## 8. Magic numbers

A magic number is a number literal whose meaning the code does not say. Every such number is a named constant. The constant has an XML comment that says what the number means and what its unit is, and a link to the page of the project documentation that explains the principle or pattern behind the number. The reader of the code then knows what the number is, and the reader of the documentation can find where it is used.

| Rule | Enforced by |
|---|---|
| A number literal with a meaning (a weight, a limit, a size, a salt, a multiplier) is a named constant: `const` when the type allows it, `static readonly` otherwise | Review (no built-in .NET analyzer checks this; a literal in an expression builds and formats clean) |
| The constant has a `<summary>` that says what the number means and its unit (or "no unit"), and a `<seealso href="..."/>` to the section of the project documentation (an ADR, a standard or a domain page) that explains it. Private constants too | Review (CS1591 covers only public members, and only when documentation files are generated) |
| If no page explains the number yet, the change that adds the constant also adds the explanation to the documentation | Review |
| Not magic numbers: `0`, `1` and `-1` used as start, end, step or identity value; test data in tests; a value assigned to a named, documented property in an object initializer, such as `TickSize = 0.005m` in the replay options | — |

```csharp
/// <summary>
/// Weight of the hourly noise layer in the replay price, as a share of the whole noise (no unit).
/// The daily layer has the rest (<see cref="DailyWeight"/>), so the two weights add up to 1.
/// </summary>
/// <seealso href="https://alexeygane.github.io/signallog/domain/replay-price-generator/#6-two-layers"/>
private const double HourlyWeight = 0.6;
```

The code on `main` does not follow this rule everywhere yet: the replay generator still has unnamed multipliers in its hash functions, and its constants have no XML comments. A separate story fixes this.

## 9. Time and identifiers

| Rule | Enforced by |
|---|---|
| The current time comes from an injected `TimeProvider` (`GetUtcNow()`); `DateTime.Now`, `DateTime.UtcNow`, `DateTime.Today`, `DateTimeOffset.Now` and `DateTimeOffset.UtcNow` are banned (ADR 0017). Tests use `FakeTimeProvider` with a fixed, real calendar date | Build (`RS0030`, an error in `.editorconfig`) |
| Event ids are UUID version 7: `Guid.CreateVersion7(timeProvider.GetUtcNow())`; `Guid.NewGuid()` is banned (ADR 0012) | Build (`RS0030`) |
| Bytes of a GUID in RFC 9562 order: `ToByteArray(bigEndian: true)`; the parameterless `ToByteArray()` is banned | Build (`RS0030`) |

The banned list is `BannedSymbols.txt`; each entry carries its reason and ADR, which the build error repeats. `eng/Test-BannedApi.ps1` is the [fitness function](concepts-and-sources.md#fitness-function) that proves the analyzer is active: it builds a probe project that calls every banned API and fails unless each of those lines fails with `RS0030`.

## 10. Regular expressions

| Rule | Enforced by |
|---|---|
| A pattern known at compile time is a `[GeneratedRegex]` on a `static partial` method: the source generator checks it when the project is built and produces matching code without run-time compilation | Review (`new Regex(...)` builds clean) |
| `RegexOptions.CultureInvariant`, and `\z`, not `$`, at the end: `$` also matches before a final line feed | Review |

```csharp
[GeneratedRegex(@"^/adapters/[a-z0-9]+(-[a-z0-9]+)*\z", RegexOptions.CultureInvariant)]
private static partial Regex AdapterSourcePattern();
```

## 11. Async and cancellation

| Rule | Enforced by |
|---|---|
| An asynchronous method takes a `CancellationToken` as its **last** parameter, named `cancellationToken` | Build (`CA1068` for the position); the name: review |
| The token is passed on to every call that accepts one | Build (`CA2016`) |
| Code under `src/` awaits with `ConfigureAwait(false)` | Review (`CA2007`, which would require it, is not in the recommended set) |
| Tests await without `ConfigureAwait(false)` and pass `TestContext.Current.CancellationToken` to every call that takes a token | Build (`xUnit1030`, `xUnit1051`) |
| No `async void`, except event handlers | Review |

## 12. Logging and tracing

| Rule | Enforced by |
|---|---|
| Log through `LoggerMessage` delegates (or the `[LoggerMessage]` source generator) with a named `EventId`, not through `LogInformation` and its siblings | Build (`CA1848`, `CA1873`) |
| The message template is a constant with named placeholders in PascalCase (`{Count}`, `{TraceId}`), never an interpolated string | Build (`CA2254`) |
| A unit of work that crosses a process runs in an `Activity` from the component's `ActivitySource`, so its trace context travels with the events (ADR 0007) | Review |

```csharp
private static readonly Action<ILogger, int, string, Exception?> LogRun = LoggerMessage.Define<int, string>(
    LogLevel.Information,
    new EventId(1, "ReplayRun"),
    "Replay adapter published {Count} price ticks in trace {TraceId}");
```

## 13. Errors

| Rule | Enforced by |
|---|---|
| An exception message says what was expected and what came: `$"Expected a UUID version 7, got version {id.Version}."` | Review |
| Catch the exceptions you can handle; no `catch (Exception)` that hides a failure | Review (a catch-all builds clean) |
| `InvalidOperationException` for a state that should be impossible, with the reason: `activity.Id ?? throw new InvalidOperationException("The adapter run has no trace context.")` | Review |

## 14. Comments

| Rule | Enforced by |
|---|---|
| Every public type and member has an XML `<summary>`. It says what the member is for and refers to the ADR, NFR or business rule behind it | Review (the build does not generate documentation files, so missing comments are not reported) |
| A code comment explains **why** or names a source (an ADR, an RFC, a paper), not what the next line does | Review |
| Units and examples are part of the comment where they help: "Price in `Currency` per `Unit`", "for example `NDEX.TFM.2026-12`" | Review |

## 15. Tests

| Rule | Enforced by |
|---|---|
| xUnit v3 on Microsoft.Testing.Platform (`global.json`); one `sealed` test class per class under test, named `<Type>Tests` | Review |
| Method names are sentences in snake case that state the behaviour: `Same_seed_and_time_give_the_same_ticks_in_another_instance` | Review (`CA1707` is off for `tests/**` to allow it) |
| One comment line above the test class says what the class proves | Review |
| Arrange, act and assert are separated by blank lines | Review |
| No real clock, no network, no random seed from the machine: `FakeTimeProvider`, a recording `HttpMessageHandler`, fixed seeds | Review; the clock: Build (`RS0030` also applies to tests) |
| A contract change is tested against its JSON Schema | Review |

## 16. Suppressions

There is no suppression in the code today, and a new one is an exception that the review has to accept.

| Rule | Enforced by |
|---|---|
| A diagnostic is fixed, not suppressed. When it cannot be, `#pragma warning disable <id>` around the smallest possible span, a comment on the same line with the reason and the ADR or issue, and `#pragma warning restore <id>` right after | Review |
| A banned API that has to be used carries `#pragma warning disable RS0030` with a comment that references the ADR (the rule at the top of `BannedSymbols.txt`) | Review |
| A severity is changed only in `.editorconfig`, with a comment that gives the reason, like the two changes there today: `RS0030` raised to error, `CA1707` turned off for tests | Review |
| No `[SuppressMessage]` without `Justification` | Review |

## Appendix A. How the enforcement was checked

On 2026-11-15, with .NET SDK 10.0.402, each rule below was broken on purpose in a probe file added to a copy of the repository (`src/SignalLog.Adapters.Core`, `src/SignalLog.Adapters` for logging, `tests/SignalLog.Adapters.Tests` for the xUnit rules), and the project was built in Release or checked with `dotnet format --verify-no-changes`. *Clean* means the build or the format check passed: only the review catches that rule.

| Probe | Build | `dotnet format` |
|---|---|---|
| `var x = 1;` | clean | clean |
| `await t;` without `ConfigureAwait(false)` | clean | — |
| A field assigned only at declaration, not `readonly` | error `IDE0044` | — |
| A private field named `x` instead of `_x` | clean | clean |
| A block-scoped namespace | clean | clean |
| An internal class that is not sealed | error `CA1852` | — |
| An instance method that uses no instance state | error `CA1822` | — |
| `new Regex("a+")` | clean | — |
| `l.LogInformation($"n {n}")` | errors `CA1848`, `CA1873`, `CA2254` | — |
| `l.LogInformation("n {N}", n)` | errors `CA1848`, `CA1873` | — |
| A call that takes a token, without passing it | error `CA2016` | — |
| `CancellationToken` as the first parameter | error `CA1068` | — |
| A public method that dereferences an unchecked parameter | clean | — |
| A local function that captures nothing, not `static` | error `IDE0062` | — |
| `this._x` | clean | — |
| `Guid.NewGuid()`, `DateTime.UtcNow` | error `RS0030` | — |
| An ignored return value without `_ =` | clean | — |
| Dereferencing a `string?` | error `CS8602` | — |
| A method named `Do_it` in `src` | error `CA1707` | — |
| A record with a `double Price` | clean | — |
| `catch (Exception)` | clean | — |
| A number literal in an expression, `0.6 * hourly` | clean | clean |
| `async void` | clean | — |
| `a.ToLower() == "x"` | errors `CA1304`, `CA1311`, `CA1862` | — |
| `d.ToString()` on a `decimal` | error `CA1305` | — |
| An unused `using` | clean | — |
| `using` directives out of order | clean | error `IMPORTS` |
| `System` and `SignalLog` usings without a blank line between them | clean | error `WHITESPACE` |
| An opening brace at the end of the line, two-space indentation | clean | error `WHITESPACE` |
| Trailing spaces | clean | error `WHITESPACE` |
| No blank line after a guard clause | clean | clean |
| `ConfigureAwait(false)` in a test | error `xUnit1030` | — |
| A test call without `TestContext.Current.CancellationToken` | error `xUnit1051` | — |
| A test method named `Method_condition_expected` | clean | — |

A rule whose probe is clean stays a review rule until someone decides to raise its severity in `.editorconfig`; that is a change to this standard and to the code, made in the same pull request.

## Sources

Checked on 2026-11-15.

- Microsoft Learn, *Code analysis in .NET* (code style analysis on build, `EnforceCodeStyleInBuild`, `AnalysisLevel`): https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview
- Microsoft Learn, *Configuration options for code analysis* (severity levels: `silent` is hidden, `suggestion` is info): https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-options
- Microsoft Learn, *Formatting rule (IDE0055)* (a severity must be `warning` or `error` to be enforced on build): https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/style-rules/ide0055
- Microsoft Learn, *dotnet format*: https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-format
- Microsoft Learn, *Recommended XML tags for C# documentation comments* (`<summary>`, `<see>`, `<seealso>`): https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/recommended-tags
- Microsoft Learn, *High-performance logging in .NET* (`LoggerMessage`): https://learn.microsoft.com/en-us/dotnet/core/extensions/high-performance-logging
- Microsoft Learn, *.NET regular expression source generators*: https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-source-generators
- Microsoft Learn, `TimeProvider` class: https://learn.microsoft.com/en-us/dotnet/api/system.timeprovider
- Microsoft Learn, `Guid.CreateVersion7` method: https://learn.microsoft.com/en-us/dotnet/api/system.guid.createversion7
- xUnit.net analyzers, xUnit1030 "Do not call ConfigureAwait in test method" and xUnit1051 "Calls to methods which accept CancellationToken should use TestContext.Current.CancellationToken": https://xunit.net/xunit.analyzers/rules/
- K. Beck, *Smalltalk Best Practice Patterns*, Prentice Hall, 1997, ISBN 978-0-13-476904-2, "Guard Clause"
