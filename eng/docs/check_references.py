"""Check citations and references in the documentation and the code (ADR 0021, references standard section 14).

Findings:
  footnote          a footnote is defined but not used, or used but not defined
  external-url      a page holds an external URL instead of a footnote to the bibliography
  uncited-source    a bibliography entry is cited by no page and not marked further_reading
  unused-concept    a concept of the concepts page is linked from no other page
  mirror            a page and its Russian mirror differ in footnote keys or explicit anchors
  code-link         code or configuration links to a site page, an anchor or a repository file that does not exist,
                    or to an anchor that is not explicit (<a id>) in the source page
  code-id           code or configuration names an ADR, NFR or BR that does not exist, or a source key
                    in a comment that is not in the bibliography
  legacy-list       a path in eng/docs/references-legacy.txt does not exist

Pages listed in eng/docs/references-legacy.txt get warnings; everything else gets errors. The exit code is 1
when there is an error. On GitHub Actions errors are also written as annotations, and warnings are folded into a group.

Usage, from the repository root:
    python eng/docs/check_references.py
"""

from __future__ import annotations

import dataclasses
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import build_references as br  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]

SITE = "https://alexeygane.github.io/signallog"
REPOSITORY = "https://github.com/AlexeyGane/signallog"
# Links to the project's own site, repository and board are navigation, not citations.
OWN_URLS = (SITE, REPOSITORY, "https://dev.azure.com/alexeygane")

LEGACY_LIST = "eng/docs/references-legacy.txt"
CONCEPTS_PAGE = "docs/standards/concepts-and-sources.md"
BIBLIOGRAPHY_PAGE = "docs/references/index.md"
SOURCES_FILE = "docs/references/sources.toml"
# English page -> Russian mirror (documentation standard, section 7).
MIRRORS = {"docs/fun-facts/index.md": "docs/fun-facts/ru.md"}

CODE_FOLDERS = ("src", "tests", "contracts", "eng/azure-devops")
CODE_SUFFIXES = {".cs", ".csproj", ".props", ".targets", ".json", ".ps1", ".psm1", ".psd1", ".yml", ".yaml", ".xml"}
SKIPPED_FOLDERS = {"bin", "obj", "node_modules", "TestResults"}

URL = re.compile(r"https?://[^\s<>()\[\]\"'`|]+")
TRAILING = ".,;:!?"
FOOTNOTE_DEFINITION = re.compile(r"^ {0,3}\[\^([^\]\s]+)\]:", re.M)
FOOTNOTE_REFERENCE = re.compile(r"\[\^([^\]\s]+)\]")
EXPLICIT_ANCHOR = re.compile(r"<a\s+id=\"([^\"]+)\"\s*>\s*</a>")
HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
CONCEPT_LINK = re.compile(r"(?:[\w./-]*/)?concepts-and-sources\.md#([a-z0-9-]+)")
SITE_LINK = re.compile(re.escape(SITE) + r"(/[^\s\"'<>()\[\]`|]*)?")
REPOSITORY_LINK = re.compile(re.escape(REPOSITORY) + r"/(?:blob|tree)/main/([^\s#?\"'<>()\[\]`|]+)")
ADR_ID = re.compile(r"\bADR[ -](\d{4})\b")
NFR_ID = re.compile(r"\bNFR-[A-Z]+-\d{2}\b")
BR_ID = re.compile(r"\bBR-[A-Z]+-\d{2}\b")
SOURCE_KEY = re.compile(r"\[([a-z][a-z0-9]+(?:-[a-z0-9]+)+)\]")
COMMENT_START = {".cs": "//", ".ps1": "#", ".psm1": "#", ".psd1": "#", ".yml": "#", ".yaml": "#"}


@dataclasses.dataclass(frozen=True, order=True)
class Finding:
    path: str
    line: int
    kind: str
    message: str
    legacy: bool = False

    @property
    def level(self) -> str:
        return "warning" if self.legacy else "error"

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.level}: [{self.kind}] {self.message}"


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def visible(markdown: str) -> str:
    """Markdown without code and HTML comments; line numbers are kept."""
    blanked = HTML_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), markdown)
    lines, inside, fence = [], False, ""
    for line in blanked.split("\n"):
        match = br.FENCE.match(line)
        if match and (not inside or match.group(1) == fence):
            inside, fence = (not inside), match.group(1)
            lines.append("")
            continue
        lines.append("" if inside else br.INLINE_CODE.sub("", line))
    return "\n".join(lines)


def strip_trailing(url: str) -> str:
    return url.rstrip(TRAILING)


def legacy_paths(root: pathlib.Path) -> tuple[set[str], list[Finding]]:
    path = root / LEGACY_LIST
    if not path.exists():
        return set(), []
    paths, findings = set(), []
    for number, line in enumerate(read(path).split("\n"), start=1):
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        paths.add(entry)
        if not (root / entry).exists():
            findings.append(Finding(LEGACY_LIST, number, "legacy-list", f"{entry} does not exist"))
    return paths, findings


def pages(root: pathlib.Path) -> list[str]:
    docs = root / "docs"
    return sorted(p.relative_to(root).as_posix() for p in docs.rglob("*.md") if p.relative_to(root).as_posix() != BIBLIOGRAPHY_PAGE)


def check_page(root: pathlib.Path, page: str, legacy: bool) -> list[Finding]:
    text = visible(read(root / page))
    findings = []
    defined = {m.group(1): m.start() for m in FOOTNOTE_DEFINITION.finditer(text)}
    used = {}
    # Blank the labels of the definitions (same length, so positions and lines stay), then every label left is a use
    references = FOOTNOTE_DEFINITION.sub(lambda m: " " * len(m.group(0)), text)
    for m in FOOTNOTE_REFERENCE.finditer(references):
        used.setdefault(m.group(1), m.start())
    for key in sorted(set(defined) - set(used)):
        findings.append(Finding(page, line_of(text, defined[key]), "footnote", f"footnote [^{key}] is defined but not used", legacy))
    for key in sorted(set(used) - set(defined)):
        findings.append(Finding(page, line_of(text, used[key]), "footnote", f"footnote [^{key}] is used but not defined", legacy))
    for m in URL.finditer(text):
        url = strip_trailing(m.group(0))
        if url.startswith(OWN_URLS) or url.startswith(("http://localhost", "http://127.0.0.1")):
            continue
        findings.append(Finding(page, line_of(text, m.start()), "external-url", f"external URL {url}: add it to sources.toml and cite it by footnote", legacy))
    return findings


def check_sources(root: pathlib.Path) -> list[Finding]:
    sources = root / SOURCES_FILE
    entries = br.load(sources)
    cited = br.citations(root / "docs", root / BIBLIOGRAPHY_PAGE)
    text = read(sources)
    findings = []
    for entry in entries:
        if entry["id"] in cited or entry.get("further_reading"):
            continue
        match = re.search(r'^id\s*=\s*"' + re.escape(entry["id"]) + '"', text, re.M)
        line = line_of(text, match.start()) if match else 1
        findings.append(Finding(SOURCES_FILE, line, "uncited-source", f"{entry['id']} is cited by no page; cite it or set further_reading = true"))
    return findings


def check_concepts(root: pathlib.Path, legacy: set[str]) -> list[Finding]:
    page = root / CONCEPTS_PAGE
    if not page.exists():
        return []
    text = read(page)
    used = set()
    for other in pages(root):
        if other != CONCEPTS_PAGE:
            used.update(CONCEPT_LINK.findall(visible(read(root / other))))
    return [
        Finding(CONCEPTS_PAGE, line_of(text, m.start()), "unused-concept", f"concept '{m.group(1)}' is linked from no other page", CONCEPTS_PAGE in legacy)
        for m in EXPLICIT_ANCHOR.finditer(text)
        if m.group(1) not in used
    ]


def check_mirrors(root: pathlib.Path, legacy: set[str]) -> list[Finding]:
    findings = []
    for page, mirror in MIRRORS.items():
        if not ((root / page).exists() and (root / mirror).exists()):
            continue
        original, translated = visible(read(root / page)), visible(read(root / mirror))
        is_legacy = page in legacy or mirror in legacy
        for what, pattern in (("footnote keys", FOOTNOTE_DEFINITION), ("explicit anchors", EXPLICIT_ANCHOR)):
            missing = set(pattern.findall(original)) - set(pattern.findall(translated))
            extra = set(pattern.findall(translated)) - set(pattern.findall(original))
            if missing:
                findings.append(Finding(mirror, 1, "mirror", f"{what} of {page} missing here: {', '.join(sorted(missing))}", is_legacy))
            if extra:
                findings.append(Finding(mirror, 1, "mirror", f"{what} not in {page}: {', '.join(sorted(extra))}", is_legacy))
    return findings


def site_page(root: pathlib.Path, path: str) -> pathlib.Path | None:
    """The Markdown source of a site path such as domain/replay-price-generator/, or a static file under docs/."""
    path = path.strip("/")
    docs = root / "docs"
    candidates = [docs / "index.md"] if not path else [docs / f"{path}.md", docs / path / "index.md", docs / path]
    return next((c for c in candidates if c.is_file()), None)


def code_files(root: pathlib.Path) -> list[pathlib.Path]:
    files = []
    for folder in CODE_FOLDERS:
        base = root / folder
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix in CODE_SUFFIXES and not SKIPPED_FOLDERS.intersection(path.relative_to(root).parts):
                files.append(path)
    return sorted(files)


def check_code(root: pathlib.Path, keys: set[str]) -> list[Finding]:
    adrs = {p.name[:4] for p in (root / "docs" / "adr").glob("[0-9][0-9][0-9][0-9]-*.md")}
    nfr_text = read(root / "docs/requirements/nfr.md") if (root / "docs/requirements/nfr.md").exists() else ""
    br_text = read(root / "docs/requirements/business-rules.md") if (root / "docs/requirements/business-rules.md").exists() else ""
    findings = []
    for path in code_files(root):
        relative = path.relative_to(root).as_posix()
        comment = COMMENT_START.get(path.suffix)
        for number, line in enumerate(read(path).split("\n"), start=1):
            for m in SITE_LINK.finditer(line):
                target = strip_trailing(m.group(1) or "/")
                address, _, anchor = target.partition("#")
                source = site_page(root, address)
                if source is None:
                    findings.append(Finding(relative, number, "code-link", f"{SITE}{target}: no such page"))
                elif anchor and anchor not in EXPLICIT_ANCHOR.findall(read(source)):
                    findings.append(Finding(relative, number, "code-link", f"{SITE}{target}: '{anchor}' is not an explicit anchor of {source.relative_to(root).as_posix()}"))
            for m in REPOSITORY_LINK.finditer(line):
                target = strip_trailing(m.group(1))
                if not (root / target).exists():
                    findings.append(Finding(relative, number, "code-link", f"{REPOSITORY}: {target} does not exist on this branch"))
            for m in ADR_ID.finditer(line):
                if m.group(1) not in adrs:
                    findings.append(Finding(relative, number, "code-id", f"{m.group(0)} does not exist"))
            for m in NFR_ID.finditer(line):
                if m.group(0) not in nfr_text:
                    findings.append(Finding(relative, number, "code-id", f"{m.group(0)} is not in docs/requirements/nfr.md"))
            for m in BR_ID.finditer(line):
                if m.group(0) not in br_text:
                    findings.append(Finding(relative, number, "code-id", f"{m.group(0)} is not in docs/requirements/business-rules.md"))
            if comment and comment in line:
                for m in SOURCE_KEY.finditer(line[line.index(comment):]):
                    if m.group(1) not in keys:
                        findings.append(Finding(relative, number, "code-id", f"source key [{m.group(1)}] is not in {SOURCES_FILE}"))
    return findings


def check(root: pathlib.Path) -> list[Finding]:
    legacy, findings = legacy_paths(root)
    for page in pages(root):
        findings += check_page(root, page, page in legacy)
    findings += check_sources(root)
    findings += check_concepts(root, legacy)
    findings += check_mirrors(root, legacy)
    keys = {entry["id"] for entry in br.load(root / SOURCES_FILE)}
    findings += check_code(root, keys)
    return sorted(findings)


def annotate(finding: Finding) -> str:
    message = finding.message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return f"::{finding.level} file={finding.path},line={finding.line},title={finding.kind}::{message}"


def main() -> int:
    try:
        findings = check(ROOT)
    except br.SourceError as error:
        print(f"{SOURCES_FILE} is invalid:\n{error}", file=sys.stderr)
        return 1
    actions = os.environ.get("GITHUB_ACTIONS") == "true"
    errors = [f for f in findings if not f.legacy]
    warnings = [f for f in findings if f.legacy]
    for finding in errors:
        print(finding)
        if actions:
            print(annotate(finding))
    if warnings:
        # Warnings are the backlog of the migration stories; on GitHub Actions they are folded into one group.
        print(f"::group::{len(warnings)} warning(s) on pages not migrated yet" if actions else f"--- {len(warnings)} warning(s) on pages not migrated yet")
        for finding in warnings:
            print(finding)
        if actions:
            print("::endgroup::")
    errors, warnings = len(errors), len(warnings)
    print(f"check_references: {errors} error(s), {warnings} warning(s) on pages in {LEGACY_LIST}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
