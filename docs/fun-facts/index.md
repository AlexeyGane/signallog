# Fun facts

[Русская версия](ru.md)

Short stories behind the words, numbers and conventions that turn up in this project. Each fact links to a source that can be checked.

## 72: the width of a commit message

The body of a commit message is wrapped at about 72 characters, and the subject line is kept to about 50. The number comes from an 80-column terminal: `git log` indents the message by 4 spaces on the left, and another 4 are left on the right for symmetry. The second reason is patches sent by email (`git format-patch`): the margin leaves room for several levels of `> ` in nested replies. A subject longer than 50 characters gets cut off in `git log --oneline`, `git shortlog`, `git rebase -i` and email subjects. This is a convention, not a rule enforced by Git; the author calls 50 "not a hard maximum".

Source: [T. Pope, A Note About Git Commit Messages, 2008-04-19](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

## Slug: a newspaper word in branch names

A slug is a short machine-friendly name made of letters, digits, underscores and hyphens, which fits into a URL or a branch name as it is. In `docs/AB11-autolink-urls`, the slug is `autolink-urls`. The word dates from hot-metal typesetting: the short name of a story was cast in large type on a single line of lead, the slug, and that line identified the story's type until it was placed on a page.

The word came to the web with Django. Django was built at World Online, the web operation of a newspaper in Lawrence, Kansas, and its field for such names is called `SlugField`. The Django documentation opens its description with "Slug is a newspaper term". The anchors on this site are slugs too: `#weighted-evaluation-method`.

Sources: [Django: SlugField](https://docs.djangoproject.com/en/stable/ref/models/fields/#slugfield), [Django: glossary, slug](https://docs.djangoproject.com/en/stable/glossary/#term-slug), [Django FAQ: history](https://docs.djangoproject.com/en/stable/faq/general/), [M. Perlman, Leading Questions, Columbia Journalism Review, 2010-11-01](https://www.cjr.org/language_corner/leading_questions.php).

## Ed25519: why "Ed" and why "25519"

"Ed" stands for Edwards. In 2007 the mathematician Harold Edwards published a new normal form for elliptic curves, x² + y² = a² + a²x²y². The equation is symmetric in x and y, and the functions that parametrise it behave like sine and cosine on a circle. In the same year Daniel Bernstein and Tanja Lange derived fast addition and doubling formulas for such curves, opening their paper with "Edwards recently introduced a new normal form"; this is how "Edwards curves" got their name. What makes them useful in cryptography is that one addition formula also handles doubling, which makes side-channel attacks harder.

"25519" is the prime 2²⁵⁵ − 19 over which the curve is defined. The Ed25519 signature scheme (Bernstein, Duif, Lange, Schwabe, Yang, 2011) uses a twisted Edwards curve that is birationally equivalent to Curve25519. The commits of SignalLog are signed with a key of this type (`id_ed25519`).

Sources: [H. M. Edwards, A normal form for elliptic curves, Bulletin of the AMS 44 (2007), 393–422](https://doi.org/10.1090/S0273-0979-07-01153-6), [D. J. Bernstein, T. Lange, Faster addition and doubling on elliptic curves, IACR ePrint 2007/286](https://eprint.iacr.org/2007/286), [P. Schwabe et al., High-speed high-security signatures, CHES 2011 (slides)](https://iacr.org/workshops/ches/ches2011/presentations/Session%203/CHES2011_Session3_2.pdf).

## Fitness function: from genetic algorithms to architecture

In evolutionary computing, a program searches for a solution the way natural selection works. Genetic algorithms, studied by John Holland (1973, 1975), proceed in generations: a set of candidates is varied at random, a fitness function scores each candidate by how close it comes to the goal, and the best ones pass to the next generation. The fitness function defines what counts as success, and whoever sets the problem chooses it.

Neal Ford, Rebecca Parsons and Patrick Kua carried the idea over to software architecture: "We borrow a concept from evolutionary computing called fitness functions". An architectural fitness function is an objective, preferably automated check of an architectural property that runs continuously; the authors liken it to a unit test for the architecture. In SignalLog, such a check is a probe project full of banned API calls: CI makes sure that every one of those lines fails to compile.

Sources: N. Ford, R. Parsons, P. Kua. *Building Evolutionary Architectures*. O'Reilly, 2017, ISBN 978-1-491-98636-3; 2nd ed., 2022, ISBN 978-1-492-09754-9 ([chapter 2, Fitness Functions](https://oreilly.com/library/view/building-evolutionary-architectures/9781492097532/ch02.html)); [MathWorld: Genetic Algorithm](https://mathworld.wolfram.com/GeneticAlgorithm.html). Sources of the project's other concepts are on the page [Concepts and their sources](../standards/concepts-and-sources.md).

## tj-actions/changed-files: how a moved tag gave away secrets

tj-actions/changed-files is a GitHub Action that reports which files changed in a commit or pull request; tens of thousands of repositories depended on it. On 14 March 2025, researchers at StepSecurity noticed that its code had been replaced: the attacker had moved the git version tags to a commit of their own. Every workflow that referenced the action by tag received foreign code on its next run; the code dumped the runner's memory and printed the secrets it found straight into the build log. Anyone can read those logs in a public repository. Secrets leaked from 218 repositories (early estimates said 23,000), mostly short-lived `GITHUB_TOKEN`s, but also a few dozen keys for DockerHub, npm and AWS.

The chain had started long before. In November–December 2024, a vulnerable `pull_request_target` workflow in the SpotBugs project let the attacker steal a maintainer's personal access token. On 11 March 2025 they used it to reach the token of a reviewdog maintainer and replaced the `v1` tag of reviewdog/action-setup. Through the dependent action tj-actions/eslint-changed-files, the token of the tj-actions bot leaked, and that token was used to move the tags of changed-files. According to Unit 42, the first target was Coinbase's open-source agentkit project; Coinbase fended the attack off. The vulnerabilities are CVE-2025-30066 and CVE-2025-30154; CISA added the first to its catalogue of exploited vulnerabilities on 18 March 2025.

The lesson for SignalLog: a tag is a movable reference that its owner (or whoever stole the owner's token) can point at any commit. A full commit hash is computed from the content, so it cannot be redirected to other code. That is why every third-party action in our workflows is referenced by its full SHA, and version updates arrive from Dependabot as separate pull requests that go through review.

Sources: [CISA, Supply Chain Compromise of Third-Party GitHub Action, CVE-2025-30066, 2025-03-18](https://cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-github-action-cve-2025-30066); [GitHub Advisory GHSA-mrrh-fwg8-r2c3](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3); [The Hacker News, 2025-03-23](https://thehackernews.com/2025/03/github-supply-chain-breach-coinbase.html); [Infosecurity Magazine: Tj-actions Supply Chain Attack Traced Back to Single GitHub Token Compromise](https://www.infosecurity-magazine.com/news/tj-actions-supply-chain-attack/).

## On the wire: why a data format is named after a wire

"On the wire" means data as it travels between systems: the bytes in a message, a request or a queue, as opposed to the object inside a program ("in memory"). The phrase goes back to the telegraph, when messages really did travel along a wire: *wire* still means a telegraph or telephone system, and also a telegram, and "to wire" means to send a message or money by telegraph. Networks took the word over, and today it names the serialized form of data, as in the "wire format" of Protocol Buffers or the "wire protocol" of a database.

In SignalLog the same timestamp has two forms. In memory it is a `DateTimeOffset`; on the wire it is the string `"2026-11-07T09:15:02.123Z"` in the JSON of a `signallog.price.tick.v1` event. That is why the pattern of that string in `UtcTimestampConverter` is called `WireFormat`: it belongs to the message contract, not to logging or the user interface.

Sources: [Merriam-Webster: wire](https://www.merriam-webster.com/dictionary/wire) (noun 5b, 5c; verb); [Protocol Buffers: Encoding](https://protobuf.dev/programming-guides/encoding/) ("This document describes the Protobuf wire format").
