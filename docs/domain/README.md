# Domain knowledge base

This section describes the commodity-market domain that SignalLog models: the vocabulary, the model, and the rules behind it. It is the place where design discussions are recorded once they are settled, so that the reasoning outlives the conversation.

| Page | What it covers |
|---|---|
| [Glossary](glossary.md) | The ubiquitous language: every domain term used in code, documents and conversations |
| [Domain model](model.md) | Entities, value objects, their relationships and invariants |
| [Time and delivery](time-and-delivery.md) | UTC versus local rules, delivery days of 23/24/25 hours, gaps and overlaps, trading days, worked examples |
| [Tenors and delivery periods](tenors-and-delivery-periods.md) | Day-ahead, weekend, balance of month, months, quarters, seasons, gas and calendar years; relative labels such as M+1 and how they roll |
| [Market conventions](market-conventions.md) | How exchanges define sessions, settlement periods, peak windows and indices; what is verified and what is open |

## How this section relates to the ADRs

- **ADRs** record *decisions*: what was chosen, the alternatives and the consequences. They are short and stable once accepted.
- **Domain pages** record *knowledge*: definitions, worked examples, market facts and open questions. They grow as the project learns.
- Each decision in an ADR links to the domain page that explains the concepts behind it, and each domain page links to the ADR that settles a choice.

## Conventions for these pages

- Every market fact cites its source (exchange specification, regulator document) and the date it was checked.
- Anything inferred rather than read in a source is marked **Inferred**; anything not yet confirmed is listed under **Open questions** on the page.
- Examples use real calendar dates so that they can be turned directly into unit tests.
- Diagrams are written in Mermaid, which GitHub and MkDocs both render.
