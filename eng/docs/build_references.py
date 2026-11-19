"""Write the bibliography page docs/references/index.md from docs/references/sources.toml.

ADR 0021 and the references standard (docs/standards/references.md): every external source is
described once, in sources.toml, and pages cite it by key in a footnote that links to
references/index.md#<key>. This script validates the entries and writes the page: one explicit
anchor per key, entries grouped by kind, and for every entry the pages that cite it.

Usage, from the repository root:
    python eng/docs/build_references.py          write the page
    python eng/docs/build_references.py --check  fail when the entries are invalid or the page is out of date

Needs only the Python standard library (tomllib, Python 3.11 or later).
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys
import tomllib

DOCS = pathlib.Path(__file__).resolve().parents[2] / "docs"

KEY = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DATE = re.compile(r"^\d{4}(?:-\d{2}(?:-\d{2})?)?$")
CITATION = re.compile(r"(?:\.\./)*references/index\.md#([a-z0-9-]+)")
FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`\n]*`")
HEADING = re.compile(r"^#\s+(.+?)\s*$", re.M)

# Groups of the page, in order: heading -> CSL types (references standard, section 3.2).
GROUPS = {
    "Standards and specifications": ("standard",),
    "Books, papers and reports": ("book", "article-journal", "paper-conference", "report"),
    "Documentation and web pages": ("webpage", "software"),
    "Posts and news": ("post-weblog", "article-newspaper"),
}
TYPES = {t for types in GROUPS.values() for t in types}

REQUIRED = ("id", "type", "title", "tier", "stability")
OPTIONAL = (
    "author", "publisher", "container-title", "volume", "issue", "page", "issued", "version",
    "doi", "isbn", "number", "url", "accessed", "archive", "further_reading", "note",
)
WEB_TYPES = {"webpage", "post-weblog", "software"}


class SourceError(ValueError):
    """An entry of sources.toml breaks the rules of the references standard."""


def load(path: pathlib.Path) -> list[dict]:
    with path.open("rb") as stream:
        data = tomllib.load(stream)
    unknown = set(data) - {"source"}
    if unknown:
        raise SourceError(f"{path.name}: unknown top-level keys {sorted(unknown)}; entries are [[source]] tables")
    entries = data.get("source", [])
    validate(entries)
    return entries


def validate(entries: list[dict]) -> None:
    """Raises SourceError with every problem found, one per line."""
    problems: list[str] = []
    seen: set[str] = set()
    for number, entry in enumerate(entries, start=1):
        name = entry.get("id") or f"entry {number}"
        for field in REQUIRED:
            if field not in entry:
                problems.append(f"{name}: missing required field '{field}'")
        for field in sorted(set(entry) - set(REQUIRED) - set(OPTIONAL)):
            problems.append(f"{name}: unknown field '{field}'")
        key = entry.get("id")
        if key is not None:
            if not isinstance(key, str) or not KEY.match(key):
                problems.append(f"{name}: id must be lower-case letters, digits and single hyphens")
            elif key in seen:
                problems.append(f"{name}: duplicate id")
            else:
                seen.add(key)
        if "type" in entry and entry["type"] not in TYPES:
            problems.append(f"{name}: type '{entry['type']}' is not one of {sorted(TYPES)}")
        if "author" not in entry and "publisher" not in entry:
            problems.append(f"{name}: needs 'author' or 'publisher'")
        if "author" in entry and not (isinstance(entry["author"], list) and entry["author"] and all(isinstance(a, str) and a for a in entry["author"])):
            problems.append(f"{name}: author must be a non-empty list of names")
        if "tier" in entry and entry["tier"] not in (1, 2, 3):
            problems.append(f"{name}: tier must be 1, 2 or 3")
        if "stability" in entry and entry["stability"] not in ("pinned", "living"):
            problems.append(f"{name}: stability must be 'pinned' or 'living'")
        if entry.get("stability") == "living" and "accessed" not in entry:
            problems.append(f"{name}: a living source needs 'accessed'")
        if entry.get("type") in WEB_TYPES and "url" not in entry:
            problems.append(f"{name}: a {entry['type']} needs 'url'")
        for field in ("issued", "accessed"):
            value = entry.get(field)
            if value is not None and not (isinstance(value, str) and DATE.match(value)):
                problems.append(f"{name}: {field} must be an ISO 8601 date written as a string (YYYY, YYYY-MM or YYYY-MM-DD)")
        for field in ("url", "archive"):
            value = entry.get(field)
            if value is not None and not (isinstance(value, str) and value.startswith("https://")):
                problems.append(f"{name}: {field} must start with https://")
        if "further_reading" in entry and not isinstance(entry["further_reading"], bool):
            problems.append(f"{name}: further_reading must be true or false")
    if problems:
        raise SourceError("\n".join(problems))


def strip_code(markdown: str) -> str:
    """Removes fenced code blocks and inline code: an example of a citation is not a citation."""
    lines, inside, fence = [], False, ""
    for line in markdown.splitlines():
        match = FENCE.match(line)
        if match and (not inside or match.group(1) == fence):
            inside, fence = (not inside), match.group(1)
            continue
        if not inside:
            lines.append(INLINE_CODE.sub("", line))
    return "\n".join(lines)


def citations(docs: pathlib.Path, page: pathlib.Path) -> dict[str, list[pathlib.Path]]:
    """Key -> Markdown pages under docs/ that link to its entry, sorted by path."""
    cited: dict[str, set[pathlib.Path]] = {}
    for path in sorted(docs.rglob("*.md")):
        if path.resolve() == page.resolve():
            continue
        for key in CITATION.findall(strip_code(path.read_text(encoding="utf-8"))):
            cited.setdefault(key, set()).add(path)
    # Sorted by the POSIX path, case-sensitive: the same order on Windows and on the Linux runner of CI
    return {key: sorted(paths, key=lambda path: path.relative_to(docs).as_posix()) for key, paths in cited.items()}


def title_of(path: pathlib.Path) -> str:
    match = HEADING.search(strip_code(path.read_text(encoding="utf-8")))
    return match.group(1) if match else path.stem


def format_entry(entry: dict) -> str:
    """One entry as a sentence-style citation: authors, title, container, publisher, date, identifiers."""
    parts: list[str] = []
    if entry.get("author"):
        parts.append(", ".join(entry["author"]) + ".")
    parts.append(f"*{entry['title']}*.")
    container = entry.get("container-title")
    if container:
        detail = container
        if entry.get("volume"):
            detail += f" {entry['volume']}"
            if entry.get("issue"):
                detail += f"({entry['issue']})"
        if entry.get("page"):
            detail += f", pp. {entry['page']}"
        parts.append(detail + ".")
    publication = [entry[field] for field in ("publisher", "number") if entry.get(field)]
    if entry.get("version"):
        publication.append(f"version {entry['version']}")
    if entry.get("issued"):
        publication.append(entry["issued"])
    if publication:
        parts.append(", ".join(publication) + ".")
    if entry.get("doi"):
        parts.append(f"[doi:{entry['doi']}](https://doi.org/{entry['doi']}).")
    if entry.get("isbn"):
        parts.append(f"ISBN {entry['isbn']}.")
    if entry.get("url"):
        parts.append(f"[{entry['url']}]({entry['url']})")
    return " ".join(parts)


def format_facts(entry: dict, cited_in: list[pathlib.Path], page: pathlib.Path) -> str:
    facts = [f"`{entry['id']}`", f"tier {entry['tier']}", entry["stability"]]
    if entry.get("accessed"):
        facts.append(f"checked {entry['accessed']}")
    if entry.get("archive"):
        facts.append(f"[archived copy]({entry['archive']})")
    if entry.get("note"):
        facts.append(entry["note"])
    if cited_in:
        links = ", ".join(f"[{title_of(path)}]({pathlib.Path(os.path.relpath(path, page.parent)).as_posix()})" for path in cited_in)
        facts.append(f"cited in {links}")
    elif entry.get("further_reading"):
        facts.append("further reading")
    else:
        facts.append("not cited yet")
    return " · ".join(facts)


def render(entries: list[dict], cited: dict[str, list[pathlib.Path]], page: pathlib.Path) -> str:
    lines = [
        "<!-- Generated by eng/docs/build_references.py from docs/references/sources.toml. Do not edit by hand. -->",
        "",
        "# Bibliography",
        "",
        "Every external source that the documentation cites, described once. A page cites an entry by its key in a footnote; "
        "the key is the anchor of the entry on this page ([references standard](../standards/references.md), [ADR 0021](../adr/0021-citation-and-reference-model.md)).",
        "",
        "Tier 1 is a primary source, tier 2 vendor technical documentation, tier 3 news used for dates of events only. "
        "A *pinned* source does not change; a *living* page can change and shows the date it was last checked against the text.",
    ]
    for heading, types in GROUPS.items():
        group = sorted((e for e in entries if e["type"] in types), key=lambda e: e["id"])
        if not group:
            continue
        lines += ["", f"## {heading}", ""]
        for entry in group:
            lines.append(f'- <a id="{entry["id"]}"></a>{format_entry(entry)}  ')
            lines.append(f"  {format_facts(entry, cited.get(entry['id'], []), page)}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail when the entries are invalid or the page is out of date")
    args = parser.parse_args(argv)
    return run(DOCS, check=args.check)


def run(docs: pathlib.Path, check: bool) -> int:
    """Validates docs/references/sources.toml and writes or checks docs/references/index.md. Returns the exit code."""
    sources, page = docs / "references" / "sources.toml", docs / "references" / "index.md"
    shown = pathlib.Path(os.path.relpath(page)).as_posix()
    try:
        entries = load(sources)
    except (SourceError, tomllib.TOMLDecodeError) as error:
        print(f"{pathlib.Path(os.path.relpath(sources)).as_posix()} is invalid:\n{error}", file=sys.stderr)
        return 1
    expected = render(entries, citations(docs, page), page)
    if check:
        current = page.read_text(encoding="utf-8").replace("\r\n", "\n") if page.exists() else ""
        if current != expected:
            print(f"{shown} is out of date: run python eng/docs/build_references.py", file=sys.stderr)
            return 1
        print(f"{shown} is up to date ({len(entries)} sources)")
        return 0
    page.write_text(expected, encoding="utf-8", newline="\n")
    print(f"Wrote {shown} ({len(entries)} sources)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
