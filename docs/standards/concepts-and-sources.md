# Concepts and their sources

Engineering, architecture, methodology and measurement concepts used in SignalLog's documents, each with a short definition, the source where it was introduced or is defined, and where the project uses it. Domain terms (instruments, tenors, gas days) are defined in the [glossary](../domain/glossary.md); vendor capabilities and limits are cited in the ADR that relies on them ([ADR conventions](../adr/README.md#conventions)).

**Rule.** A concept used in a document either links to this page or cites its own source. A concept that is added to a document is added here in the same pull request.

Sources were checked on 2026-11-04. For books the ISBN is given for the edition that introduced the concept; a later edition is listed where the project relies on it.

## Architecture and decisions

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="adr"></a>**Architecture Decision Record (ADR)** | A short document that records one architecturally significant decision with its context and consequences. | M. Nygard, *Documenting Architecture Decisions*, 2011 — https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions | [ADR log](../adr/README.md) |
| <a id="madr"></a>**MADR** | Markdown Architectural Decision Records: an ADR template with decision drivers, considered options and their pros and cons. | MADR 4 — https://adr.github.io/madr/ | [ADR template](../adr/template.md) |
| <a id="fitness-function"></a>**Architectural fitness function** | An objective, preferably automated check of an architectural characteristic, run continuously so that the architecture cannot drift unnoticed. The term is borrowed from evolutionary computing, where a fitness function scores candidate solutions. | N. Ford, R. Parsons, P. Kua, *Building Evolutionary Architectures*, O'Reilly, 2017, **ISBN 978-1-491-98636-3** (first edition, where the term was introduced for software architecture; ch. 2 "Fitness Functions"). Second edition with P. Sadalage, 2022, ISBN 978-1-492-09754-9. Thoughtworks Technology Radar, *Architectural fitness function* — https://www.thoughtworks.com/radar/techniques/architectural-fitness-function | [ADR 0012](../adr/0012-message-contract-and-versioning.md) (banned-API analyzer), [ADR 0017](../adr/0017-time-and-timezones.md), [template](../adr/template.md) |
| <a id="c4"></a>**C4 model** | Four levels of architecture diagrams: system context, containers, components, code. | S. Brown, *The C4 model for visualising software architecture* — https://c4model.com/ | *Traces to* fields of the ADRs, [ADR 0001](../adr/0001-documentation-platform.md) |
| <a id="quality-attribute-scenario"></a>**Quality-attribute scenario** | A testable statement of a quality requirement: source, stimulus, environment, artifact, response and response measure. | L. Bass, P. Clements, R. Kazman, *Software Architecture in Practice*, 4th ed., Addison-Wesley, 2021, ISBN 978-0-13-688609-9 (scenarios were introduced in earlier editions; the 4th is the one used here) | [Requirements README](../requirements/README.md), [NFR catalogue](../requirements/nfr.md) |
| <a id="iso-25010"></a>**ISO/IEC 25010** | Product quality model: quality characteristics and sub-characteristics used to classify NFRs. | ISO/IEC 25010:2023 — https://www.iso.org/standard/78176.html | [NFR catalogue](../requirements/nfr.md) |
| <a id="ubiquitous-language"></a>**Ubiquitous language** | One vocabulary shared by domain experts and code, used with the same meaning in conversation, documents and type names. | E. Evans, *Domain-Driven Design: Tackling Complexity in the Heart of Software*, Addison-Wesley, 2003, ISBN 978-0-321-12521-7 | [Glossary](../domain/glossary.md) |

## Decision analysis

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="weighted-sum"></a>**Weighted-sum evaluation** | Each option's score is the sum of criterion scores multiplied by criterion weights. With an ordinal 1–5 scale the result orders options; it is not a measurement. | D. von Winterfeldt, W. Edwards, *Decision Analysis and Behavioral Research*, Cambridge University Press, 1986, ISBN 978-0-521-27304-6 (multi-attribute utility, additive model) | [Weighted evaluation method](../adr/README.md#weighted-evaluation-method) |
| <a id="swing-weighting"></a>**Swing weighting** | Weights are set by comparing, per criterion, the value of moving from the worst to the best plausible outcome, so that weights reflect the range actually at stake. | von Winterfeldt and Edwards, 1986, ISBN 978-0-521-27304-6 (as above) | [Weighted evaluation method](../adr/README.md#weighted-evaluation-method), ADR [0018](../adr/0018-latency-and-freshness-targets.md), [0019](../adr/0019-market-status-events.md) |
| <a id="sensitivity-analysis"></a>**Sensitivity analysis, dominance** | Checking how far weights must change before the preferred option changes; an option dominates another if it scores at least as well on every criterion. | von Winterfeldt and Edwards, 1986 (as above) | ADR [0018](../adr/0018-latency-and-freshness-targets.md), [0019](../adr/0019-market-status-events.md) |

## Delivery and flow

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="scrumban"></a>**Scrumban** | A pull-based flow that keeps selected Scrum practices and adds Kanban's visualised workflow and WIP limits. | C. Ladas, *Scrumban: Essays on Kanban Systems for Lean Software Development*, Modus Cooperandi Press, 2009, ISBN 978-0-578-00214-9 | [ADR 0003](../adr/0003-application-lifecycle-management.md) |
| <a id="kanban"></a>**Kanban, WIP limit, cycle time** | Visualised workflow; an explicit limit on work items in progress per state; elapsed time from start to finish of one item. | *The Kanban Guide* (D. Vacanti, Y. Coleman), 2020 — https://kanbanguides.org/ ; Scrum.org, *The Kanban Guide for Scrum Teams* — https://www.scrum.org/resources/kanban-guide-scrum-teams | [ADR 0003](../adr/0003-application-lifecycle-management.md), [branching standard](branching-and-release.md) |
| <a id="littles-law"></a>**Little's law** | Average work in progress = average throughput × average cycle time, for a stable system. | J. D. C. Little, "A Proof for the Queuing Formula: L = λW", *Operations Research* 9(3):383–387, 1961, doi:10.1287/opre.9.3.383 | Flow metrics ([ADR 0003](../adr/0003-application-lifecycle-management.md)) |
| <a id="trunk-based-development"></a>**Trunk-based development** | All developers integrate into one branch (`main`) at least daily, through short-lived branches. | P. Hammant et al., *Trunk Based Development* — https://trunkbaseddevelopment.com/ | [Branching standard](branching-and-release.md), [ADR 0002](../adr/0002-source-control-platform.md) |
| <a id="conventional-commits"></a>**Conventional Commits** | A commit-message format (`type(scope): subject`) that tools can parse. | https://www.conventionalcommits.org/ | [Branching standard](branching-and-release.md) |
| <a id="semver"></a>**Semantic Versioning** | `MAJOR.MINOR.PATCH`, with rules for when each part changes. | https://semver.org/ | [Branching standard](branching-and-release.md) |
| <a id="docs-as-code"></a>**Docs-as-code** | Documentation written in plain-text formats, versioned with the code and reviewed in pull requests. | Write the Docs, *Docs as Code* — https://www.writethedocs.org/guide/docs-as-code/ | [ADR 0001](../adr/0001-documentation-platform.md) |

## Integration and resilience

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="eip"></a>**Publish-subscribe channel, idempotent receiver, dead letter channel** | Messaging patterns: one message delivered to every subscriber; a receiver that processes a duplicate without side effects; a channel for messages that cannot be delivered. | G. Hohpe, B. Woolf, *Enterprise Integration Patterns*, Addison-Wesley, 2003, ISBN 978-0-321-20068-6 | [ADR 0009](../adr/0009-event-driven-ingestion.md), [ADR 0008](../adr/0008-data-storage.md) |
| <a id="circuit-breaker"></a>**Circuit breaker** | A wrapper that stops calling a failing dependency for a period after repeated failures, then probes it before closing again. | M. Nygard, *Release It!*, Pragmatic Bookshelf, 2007, ISBN 978-0-9787392-1-8; 2nd ed., 2018, ISBN 978-1-68050-239-8 | [ADR 0013](../adr/0013-adapter-control-plane.md), [NFR-REL-02](../requirements/nfr.md) |
| <a id="backoff-jitter"></a>**Exponential backoff with jitter** | Retry delays that grow exponentially and are randomised, so that clients do not retry in lockstep. | M. Brooker, *Exponential Backoff And Jitter*, AWS Architecture Blog, 2015 — https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/ | [ADR 0013](../adr/0013-adapter-control-plane.md) |
| <a id="cloudevents"></a>**CloudEvents** | A specification for describing event data in a common envelope. | CNCF, CloudEvents 1.0 — https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md | [ADR 0012](../adr/0012-message-contract-and-versioning.md) |
| <a id="trace-context"></a>**W3C Trace Context (`traceparent`)** | An HTTP header format that carries a trace id and parent span id across services. | W3C Recommendation, *Trace Context* — https://www.w3.org/TR/trace-context/ | [ADR 0007](../adr/0007-observability.md), [ADR 0012](../adr/0012-message-contract-and-versioning.md) |
| <a id="uuidv7"></a>**UUID version 7** | A time-ordered UUID: 48-bit Unix millisecond timestamp followed by random bits. | RFC 9562 — https://www.rfc-editor.org/rfc/rfc9562 | [ADR 0012](../adr/0012-message-contract-and-versioning.md) |

## Security

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="least-privilege"></a>**Least privilege** | Every principal holds only the permissions its task needs. | J. H. Saltzer, M. D. Schroeder, "The Protection of Information in Computer Systems", *Proceedings of the IEEE* 63(9), 1975, doi:10.1109/PROC.1975.9939 | [ADR 0005](../adr/0005-identity-and-access.md), [NFR-SEC-02](../requirements/nfr.md) |
| <a id="stride"></a>**STRIDE** | Threat categories: spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege. Introduced at Microsoft by L. Kohnfelder and P. Garg (1999). | A. Shostack, *Threat Modeling: Designing for Security*, Wiley, 2014, ISBN 978-1-118-80999-0; Microsoft, *Threat Modeling Tool threats* — https://learn.microsoft.com/azure/security/develop/threat-modeling-tool-threats | [ADR 0005](../adr/0005-identity-and-access.md) |
| <a id="oauth"></a>**OAuth 2.0, PKCE, OpenID Connect** | Delegated authorization; proof key for public clients using the authorization code flow; an identity layer on top of OAuth 2.0. | RFC 6749 — https://www.rfc-editor.org/rfc/rfc6749 ; RFC 7636 — https://www.rfc-editor.org/rfc/rfc7636 ; OpenID Connect Core 1.0 — https://openid.net/specs/openid-connect-core-1_0.html | [ADR 0005](../adr/0005-identity-and-access.md) |

## Standards for data formats and identifiers

| Concept | Definition (as used here) | Source | Used in |
|---|---|---|---|
| <a id="iso-8601"></a>**ISO 8601** | Text format for dates and times, for example `2026-10-25T00:30:00Z`. | ISO 8601 — https://www.iso.org/iso-8601-date-and-time-format.html | [ADR 0017](../adr/0017-time-and-timezones.md) |
| <a id="tzdb"></a>**IANA Time Zone Database (tzdb)** | The reference database of time-zone rules, identified by names such as `Europe/Amsterdam`. | https://www.iana.org/time-zones | [ADR 0017](../adr/0017-time-and-timezones.md) |
| <a id="mic"></a>**MIC (ISO 10383)** | Market Identifier Code: a four-character code for a trading venue or segment. | ISO 20022 registration authority, *Market Identifier Codes* — https://www.iso20022.org/market-identifier-codes | [ADR 0014](../adr/0014-instrument-domain-model.md), [glossary](../domain/glossary.md) |
| <a id="units"></a>**British thermal unit, therm, barrel** | 1 Btu (International Table) = 1,055.055 852 62 J; 1 therm = 10⁵ Btu; 1 barrel (oil) = 42 US gallons = 158.987 294 928 L. | NIST Special Publication 811, *Guide for the Use of the International System of Units*, Appendix B — https://www.nist.gov/pml/special-publication-811 | [Glossary](../domain/glossary.md) |
