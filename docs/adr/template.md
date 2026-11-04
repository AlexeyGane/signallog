# NNNN — <Short decision title>

| Field | Value |
|---|---|
| Status | Proposed \| Accepted \| Deprecated \| Superseded by [NNNN](NNNN-title.md) |
| Date | YYYY-MM-DD |
| Deciders | Solution Architect, Key Developer *(both roles held by one person — see README)* |
| Supersedes | — |
| Related | [NNNN](NNNN-title.md) |
| Traces to | NFR-xx, C4 container/component, Azure Boards Epic #nnn |

## Context and Problem Statement

What forces are at play? What question does this ADR answer? 2–4 sentences, written so that a reader who joins the project in a year understands why this mattered.

## Decision Drivers

Each driver should be testable or traceable to an NFR / ADR-0000 budget line.

- Driver 1
- Driver 2

## Considered Options

1. Option A
2. Option B
3. Option C

## Decision Outcome

**Chosen option:** "Option A", because <one sentence tied to the drivers>.

### Weighted evaluation

Optional. Follow the [weighted evaluation method](README.md#weighted-evaluation-method): criteria from drivers, weights fixed before scoring, anchored scale, sensitivity line.

*Expert judgement (one assessor), not a measurement.*

Weights (swing weighting, fixed before scoring):

| Criterion | Driver | Weight | Why this weight |
|---|---|---|---|
| <criterion> | D1 | 40 | <worst-to-best difference on this driver, compared with the others> |
| <criterion> | D2 | 35 | … |
| <criterion> | D3 | 25 | … |

Scale anchors:

| Criterion | 1 | 3 | 5 |
|---|---|---|---|
| <criterion> | <observable meaning> | … | … |

| Criterion (weight) | Option A | Option B | Option C |
|---|---|---|---|
| <criterion> (40) | 4 | 3 | 2 |
| <criterion> (35) | 3 | 4 | 2 |
| <criterion> (25) | 5 | 2 | 3 |
| **Weighted score** | **3.90** | **3.10** | **2.25** |

Drivers not scored: <driver on which all options are equal, or "none">.

Sensitivity: <which options the winner dominates; for each other option, the weight condition under which it would win, and whether that condition is plausible>.

Keep 2–3 honest pros and cons per option; an option that collects eight cons while the winner has none reads as a post-hoc justification.

### Consequences

- Good, because …
- Bad, because …
- Risk: … (mitigation: …)

### Confirmation

How we will know the decision is implemented and still holds: a [fitness function](../standards/concepts-and-sources.md#fitness-function), a pipeline check, a dashboard, a review trigger.

## Pros and Cons of the Options

### Option A
- Good, because …
- Bad, because …

### Option B
- Good, because …
- Bad, because …

## More Information

Links to evidence (vendor docs, pricing pages), open questions, review triggers.
