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
| **Build** | `dotnet build` with `TreatWarningsAsErrors`, `AnalysisLevel` `latest-recommended`, `EnforceCodeStyleInBuild`, `GenerateDocumentationFile`, `Nullable`, `WarningsAsErrors` for `IDE0320` and the banned-API analyzer (`Directory.Build.props`); two rules of StyleCop.Analyzers and one of Microsoft.VisualStudio.Threading.Analyzers (`Directory.Packages.props`)[^ms-dotnet-code-analysis] | Every compiler and analyzer diagnostic at warning or error severity: nullability, the recommended .NET code-quality rules (`CA*`) and the ones `.editorconfig` raises to `warning`, the code-style rules whose severity in `.editorconfig` is `warning` (`IDE*`, including the naming rules), lambdas that can be `static` (`IDE0320`, raised in the compiler options), missing XML comments on public members (`CS1591`), banned APIs (`RS0030`), one type per file (`SA1402`, `SA1649`), no `async void` (`VSTHRD100`), the xUnit analyzers in test projects |
| **Format** | `dotnet format SignalLog.slnx --verify-no-changes`, which fails when a file would change[^ms-dotnet-format] | Whitespace (indentation, braces on their own lines, trailing spaces, blank lines between `using` groups), the order of `using` directives, and the code-style rules `IDE0049` and `IDE0003`, which the build cannot report: they only surface in the IDE, even with code-style analysis on build[^ms-ide0049][^ms-ide0003-ide0009] |
| **Review** | The owner reading the pull request, file by file ([change workflow, section 5](change-workflow.md#5-review-gate-a-resolved-thread-per-file)) | Everything else, including every `.editorconfig` preference at severity `silent` or `suggestion`: the editor may show it, nothing blocks it[^ms-dotnet-code-analysis-options] |

Both Build and Format run in the `build` job of `ci.yml`, which every pull request must pass, and on the owner's machine before every commit (`Invoke-SolutionCheck`). The *Enforced by* entries below were checked with .NET SDK 10.0.402, on 2026-11-15, on 2026-11-19 after rules were moved from the review to the build, on 2026-11-22 after the review of that change, and on 2026-11-25 for `IDE0320`: each rule was broken on purpose in a probe file and the build or `dotnet format` was run; [Appendix A](#appendix-a-how-the-enforcement-was-checked) lists every probe and its result.

A code-style rule (`IDE*`) is enforced on build only at the severity `warning` or `error`.[^ms-ide0055] Here the severity is the suffix of the rule's option in `.editorconfig`, for example `csharp_style_namespace_declarations = file_scoped:warning`. Microsoft Learn also shows the form `dotnet_diagnostic.IDE0040.severity = warning`,[^ms-dotnet-code-analysis-enable] but in the probes a line `dotnet_diagnostic.IDE0161.severity = warning` alone did not make the rule fail the build, so this standard uses the option suffix.

## 2. Layout

| Rule | Enforced by |
|---|---|
| Four spaces, no tabs; every brace on its own line (Allman style); a final newline; no trailing whitespace | Format |
| `using` directives outside the namespace, `System` first, groups separated by a blank line, sorted within a group | Format (order and blank lines); placement: review |
| One file-scoped namespace per file (`namespace SignalLog.Contracts;`), matching the folder | Build (`IDE0161` for the namespace form, `IDE0130` for the match with the folder) |
| Braces on every `if`, `else`, `for`, `foreach` and `while` body, also for one statement | Build (`IDE0011`) |
| Methods, constructors and local functions have block bodies; properties, accessors, indexers and lambdas are expression-bodied | Build for methods, constructors and local functions (`IDE0022`, `IDE0021`, `IDE0061`); the rest: review |
| One type per file, named like the file, with no exceptions: a class, record, interface, struct, enum or delegate gets its own file. A nested type, such as a test double inside a test class, is a member of its type and stays in its file | Build (`SA1402`, `SA1649` of StyleCop.Analyzers; `stylecop.json` lists the kinds of type that count, because by default `SA1402` lets a delegate, enum, struct or interface share a file with a class)[^stylecop-sa1402][^stylecop-sa1649] |

```csharp
using System.Diagnostics;

using SignalLog.Contracts;

namespace SignalLog.Adapters.Core;
```

## 3. Guard clauses

A public method or constructor checks its preconditions first and leaves early when they fail: the [guard clause](concepts-and-sources.md#guard-clause).[^beck-1997] The checks stand together at the top, and **one blank line** separates them from the rest of the body, so the reader sees at a glance where the preconditions end and the work begins.

| Rule | Enforced by |
|---|---|
| Reference parameters of public members are checked with `ArgumentNullException.ThrowIfNull`; other preconditions throw `ArgumentException` or `ArgumentOutOfRangeException` with `nameof(parameter)` and a message that says what was expected and what came | Build for the null check: CA1062 ("Validate arguments of public methods") is not enabled by default,[^ms-ca1062] and `latest-recommended` does not raise it either, so `.editorconfig` raises it to `warning`. It also fires for a parameter of type `string` when nullable reference types are on. It is off for tests, whose methods get their arguments from the test framework. The messages: review |
| A blank line after the last guard clause | Build when the guard clause is a block, such as `if (...) { return; }` (`IDE2003`, an experimental rule that requires a blank line after a block[^ms-ide2003]); review after a `ThrowIfNull` line, which is not a block |
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
| Explicit types everywhere: no `var`. The type on the left is the documentation of the line | Build (`IDE0008`) |
| `new()` without the type name when the type is already on the left: `List<CloudEvent<PriceTickData>> events = new(ticks.Count);` | Build (`IDE0090`) |
| A return value that is ignored on purpose is discarded explicitly: `_ = activity.SetTag(...)` | Build (`IDE0058`); off for `tests/**`, where `Assert` methods return the checked value and a test needs only the check |
| Language keywords for built-in types (`string`, `int`), not `String`, `Int32` | Format (`IDE0049`). The build cannot report it: the rule only surfaces in the IDE, even with code-style analysis on build, and `dotnet format` runs the IDE analyzers |
| No `this.` qualification | Format (`IDE0003`). The build cannot report it, for the same reason as `IDE0049` |

## 5. Naming

The naming rules in `.editorconfig` have the severity `warning`, so a wrong name fails the build (`IDE1006`). The recommended analyzers also forbid underscores in identifiers (CA1707). Both have exceptions for test projects, whose method names are sentences.

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
| The styles in the table | Build (`IDE1006`) |
| No underscores in identifiers outside test projects | Build (`CA1707`; turned off for `tests/**` in `.editorconfig`) |
| `Async` suffix | Build (`IDE1006`, naming rule `async_methods_should_end_in_async`); off for `tests/**`, where a test method is named by the behaviour it proves |

## 6. Classes, records and members

| Rule | Enforced by |
|---|---|
| Classes are `sealed` unless they are designed for inheritance | Build for internal classes (`CA1852`); review for public classes |
| Data without behaviour is a `sealed record`; contract types use `required` `init` properties so that a missing field is a compile error | Review |
| A primary constructor when the class only stores its arguments (`RecordingHandler(HttpStatusCode status)` in the tests); an explicit constructor with guard clauses when it must check them | Review |
| Fields that are assigned only in the constructor are `readonly` | Build (`IDE0044`, severity `warning`) |
| A member that uses no instance state is `static` | Build (`CA1822`) |
| Local functions that capture nothing are `static` | Build (`IDE0062`, severity `warning`) |
| Lambdas that capture nothing are `static`: `Select(static e => e.Id)` | Build (`IDE0320`). The analyzer reports it at the severity Hidden whatever `.editorconfig` says (dotnet/roslyn#76222;[^roslyn-76222] the fix was merged into Roslyn on 2026-11-23 and is not in SDK 10.0.402[^roslyn-9d42b6a]), so `Directory.Build.props` adds `IDE0320` to `WarningsAsErrors`, and the option keeps the severity `true:warning`, without which the analyzer skips the analysis (Appendix A). `dotnet format` does not report it |
| Accessibility modifiers are always written | Build (`IDE0040`) |

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
/// <seealso href="https://alexeygane.github.io/signallog/domain/replay-price-generator/#two-layers"/>
private const double HourlyWeight = 0.6;
```

The code on `main` does not follow this rule everywhere yet: the replay generator still has unnamed multipliers in its hash functions, and its constants have no XML comments. A separate story fixes this.

## 9. Time and identifiers

| Rule | Enforced by |
|---|---|
| The current time comes from an injected `TimeProvider` (`GetUtcNow()`); `DateTime.Now`, `DateTime.UtcNow`, `DateTime.Today`, `DateTimeOffset.Now` and `DateTimeOffset.UtcNow` are banned (ADR 0017). Tests use `FakeTimeProvider` with a fixed, real calendar date[^ms-timeprovider] | Build (`RS0030`, an error in `.editorconfig`) |
| Event ids are UUID version 7: `Guid.CreateVersion7(timeProvider.GetUtcNow())`, which creates a version 7 GUID under RFC 9562 from the given time;[^ms-guid-createversion7] `Guid.NewGuid()` is banned (ADR 0012) | Build (`RS0030`) |
| Bytes of a GUID in RFC 9562 order: `ToByteArray(bigEndian: true)`; the parameterless `ToByteArray()` is banned | Build (`RS0030`) |

The banned list is `BannedSymbols.txt`; each entry carries its reason and ADR, which the build error repeats. `eng/Test-BannedApi.ps1` is the [fitness function](concepts-and-sources.md#fitness-function) that proves the analyzer is active: it builds a probe project that calls every banned API and fails unless each of those lines fails with `RS0030`.

## 10. Regular expressions

| Rule | Enforced by |
|---|---|
| A pattern known at compile time is a `[GeneratedRegex]` on a `static partial` method: the source generator checks it when the project is built and produces matching code without run-time compilation[^ms-regex-source-generators] | Build (`SYSLIB1045`, raised to `warning` in `.editorconfig`) |
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
| Code under `src/` awaits with `ConfigureAwait(false)` | Build (`CA2007`, raised to `warning` in `.editorconfig`; off for `tests/**`) |
| Tests await without `ConfigureAwait(false)` and pass `TestContext.Current.CancellationToken` to every call that takes a token | Build (`xUnit1030`, `xUnit1051`)[^xunit-analyzers] |
| No `async void`, also not for event handlers. An event handler that has to await is an exception under [section 16](#16-suppressions): `#pragma warning disable VSTHRD100` with the reason | Build (`VSTHRD100` of Microsoft.VisualStudio.Threading.Analyzers)[^vs-threading-vsthrd100] |

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

Microsoft Learn recommends the `[LoggerMessage]` source generator for new code: it avoids boxing and parses the template at compile time. `LoggerMessage.Define`, which the example uses, stays supported for existing code.[^ms-high-performance-logging]

## 13. Errors

| Rule | Enforced by |
|---|---|
| An exception message says what was expected and what came: `$"Expected a UUID version 7, got version {id.Version}."` | Review |
| Catch the exceptions you can handle; no `catch (Exception)` that hides a failure | Build (`CA1031`, raised to `warning` in `.editorconfig`) |
| `InvalidOperationException` for a state that should be impossible, with the reason: `activity.Id ?? throw new InvalidOperationException("The adapter run has no trace context.")` | Review |

## 14. Comments

| Rule | Enforced by |
|---|---|
| Every public type and member has an XML `<summary>`.[^ms-xmldoc-recommended-tags] It says what the member is for and refers to the ADR, NFR or business rule behind it | Build for the presence of the comment (`CS1591`; `GenerateDocumentationFile` is on; off for `tests/**`); its content: review |
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
| A severity is changed only in `.editorconfig`, with a comment that gives the reason, like the changes there today: `RS0030` raised to error, the rules raised from review to the build, and the exceptions for tests | Review |
| No `[SuppressMessage]` without `Justification` | Review |

## Appendix A. How the enforcement was checked

On 2026-11-15, 2026-11-19, 2026-11-22 and 2026-11-25, with .NET SDK 10.0.402, each rule below was broken on purpose in a probe file added to a copy of the repository (`src/SignalLog.Adapters.Core`, `src/SignalLog.Adapters` for logging, `tests/SignalLog.Adapters.Tests` for the xUnit rules), and the project was built in Release or checked with `dotnet format --verify-no-changes`. *Clean* means the build or the format check passed: only the review catches that rule.

| Probe | Build | `dotnet format` |
|---|---|---|
| `var x = 1;` | error `IDE0008` | clean |
| `await t;` without `ConfigureAwait(false)` in `src` | error `CA2007` | — |
| A field assigned only at declaration, not `readonly` | error `IDE0044` | — |
| A private field named `x` instead of `_x` | error `IDE1006` | clean |
| A block-scoped namespace | error `IDE0161` | clean |
| An internal class that is not sealed | error `CA1852` | — |
| An instance method that uses no instance state | error `CA1822` | — |
| `new Regex("a+")` | error `SYSLIB1045` | — |
| `l.LogInformation($"n {n}")` | errors `CA1848`, `CA1873`, `CA2254` | — |
| `l.LogInformation("n {N}", n)` | errors `CA1848`, `CA1873` | — |
| A call that takes a token, without passing it | error `CA2016` | — |
| `CancellationToken` as the first parameter | error `CA1068` | — |
| A public method that dereferences an unchecked parameter | error `CA1062` | — |
| A local function that captures nothing, not `static` | error `IDE0062` | — |
| `this._x` | clean | error `IDE0003` |
| `Int32` instead of `int` | clean | error `IDE0049` |
| A lambda that captures nothing, not `static` (`M(x => x + 1)`, the example of the `IDE0320` page[^ms-ide0320]), with `WarningsAsErrors` for `IDE0320` | error `IDE0320` | clean |
| The same lambda without `WarningsAsErrors` (2026-11-22, before the workaround) | clean | clean |
| The same lambda with `WarningsAsErrors`, and the option `true`, `true:suggestion` or `true:silent` instead of `true:warning` | clean | — |
| `Guid.NewGuid()`, `DateTime.UtcNow` | error `RS0030` | — |
| An ignored return value without `_ =` in `src` | error `IDE0058` | — |
| Dereferencing a `string?` | error `CS8602` | — |
| A method named `Do_it` in `src` | error `CA1707` | — |
| A record with a `double Price` | clean | — |
| `catch (Exception)` | error `CA1031` | — |
| A number literal in an expression, `0.6 * hourly` | clean | clean |
| An `async void` method | error `VSTHRD100` | — |
| `a.ToLower() == "x"` | errors `CA1304`, `CA1311`, `CA1862` | — |
| `d.ToString()` on a `decimal` | error `CA1305` | — |
| An unused `using` | error `IDE0005` | — |
| A public member without an XML comment in `src` | error `CS1591` | — |
| An `if` without braces | error `IDE0011` | — |
| A namespace that does not match the folder | error `IDE0130` | — |
| A second type in a file (an enum after a class) | error `SA1402` | — |
| A file whose type has another name | error `SA1649` | — |
| An expression-bodied method, constructor or local function | errors `IDE0022`, `IDE0021`, `IDE0061` | — |
| A member without an accessibility modifier | error `IDE0040` | — |
| `List<int> l = new List<int>();` | error `IDE0090` | — |
| An `async` method in `src` named without `Async` | error `IDE1006` | — |
| A statement right after a block `}` | error `IDE2003` | — |
| `using` directives out of order | clean | error `IMPORTS` |
| `System` and `SignalLog` usings without a blank line between them | clean | error `WHITESPACE` |
| An opening brace at the end of the line, two-space indentation | clean | error `WHITESPACE` |
| Trailing spaces | clean | error `WHITESPACE` |
| No blank line after a `ThrowIfNull` guard clause | clean | clean |
| `ConfigureAwait(false)` in a test | error `xUnit1030` | — |
| A test call without `TestContext.Current.CancellationToken` | error `xUnit1051` | — |
| A test method named `Method_condition_expected` | clean | — |

A rule whose probe is clean stays a review rule until someone decides to raise its severity in `.editorconfig`; that is a change to this standard and to the code, made in the same pull request.

[^ms-dotnet-code-analysis]: [Microsoft Learn, Code analysis in .NET](../references/index.md#ms-dotnet-code-analysis): `EnforceCodeStyleInBuild` and `AnalysisLevel` `latest-Recommended`.
[^ms-dotnet-format]: [Microsoft Learn, dotnet format](../references/index.md#ms-dotnet-format), option `--verify-no-changes`.
[^ms-ide0049]: [Microsoft Learn, IDE0049](../references/index.md#ms-ide0049), note on build enforcement.
[^ms-ide0003-ide0009]: [Microsoft Learn, IDE0003 and IDE0009](../references/index.md#ms-ide0003-ide0009), note on build enforcement.
[^ms-dotnet-code-analysis-options]: [Microsoft Learn, Configuration options for code analysis](../references/index.md#ms-dotnet-code-analysis-options), table of severity levels: `suggestion` is a build message, `silent` is not shown.
[^ms-ide0055]: [Microsoft Learn, IDE0055](../references/index.md#ms-ide0055): the severity must be `warning` or `error` to be enforced on build.
[^ms-dotnet-code-analysis-enable]: [Microsoft Learn, Code analysis in .NET](../references/index.md#ms-dotnet-code-analysis), section on code-style analysis on build.
[^stylecop-sa1402]: [StyleCop Analyzers, SA1402](../references/index.md#stylecop-sa1402).
[^stylecop-sa1649]: [StyleCop Analyzers, SA1649](../references/index.md#stylecop-sa1649).
[^beck-1997]: [K. Beck, Smalltalk Best Practice Patterns](../references/index.md#beck-1997), pattern "Guard Clause".
[^ms-ca1062]: [Microsoft Learn, CA1062](../references/index.md#ms-ca1062), rule properties: not enabled by default in .NET 10.
[^ms-ide2003]: [Microsoft Learn, IDE2003](../references/index.md#ms-ide2003): the rule is experimental and subject to change or removal.
[^roslyn-76222]: [dotnet/roslyn#76222](../references/index.md#roslyn-76222).
[^roslyn-9d42b6a]: [dotnet/roslyn, commit 9d42b6a](../references/index.md#roslyn-9d42b6a), pull request #86568.
[^ms-timeprovider]: [Microsoft Learn, TimeProvider Class](../references/index.md#ms-timeprovider), remarks: `FakeTimeProvider` for testing time-dependent code.
[^ms-guid-createversion7]: [Microsoft Learn, Guid.CreateVersion7](../references/index.md#ms-guid-createversion7).
[^ms-regex-source-generators]: [Microsoft Learn, .NET regular expression source generators](../references/index.md#ms-regex-source-generators).
[^xunit-analyzers]: [xUnit.net analyzer rules](../references/index.md#xunit-analyzers): xUnit1030 and xUnit1051.
[^vs-threading-vsthrd100]: [vs-threading, VSTHRD100](../references/index.md#vs-threading-vsthrd100).
[^ms-high-performance-logging]: [Microsoft Learn, High-performance logging in .NET](../references/index.md#ms-high-performance-logging).
[^ms-xmldoc-recommended-tags]: [Microsoft Learn, Recommended XML tags](../references/index.md#ms-xmldoc-recommended-tags): at a minimum, types and members have a `<summary>`.
[^ms-ide0320]: [Microsoft Learn, IDE0320](../references/index.md#ms-ide0320), example.
