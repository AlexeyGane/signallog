"""Tests of eng/docs/build_references.py (ADR 0021). Run from the repository root:

    python -m unittest discover -s eng/docs/tests -v
"""

import contextlib
import io
import pathlib
import sys
import tempfile
import textwrap
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import build_references as br  # noqa: E402

PAGE_ENTRY = {"id": "ms-topic", "type": "webpage", "title": "A page", "publisher": "Microsoft Learn",
              "url": "https://learn.microsoft.com/topic", "accessed": "2026-11-19", "tier": 2, "stability": "living"}
RFC_ENTRY = {"id": "rfc-9562", "type": "standard", "title": "UUIDs", "author": ["K. Davis"], "publisher": "IETF",
             "number": "RFC 9562", "issued": "2024-05", "url": "https://www.rfc-editor.org/rfc/rfc9562", "tier": 1, "stability": "pinned"}

SOURCES = '''
[[source]]
id        = "rfc-9562"
type      = "standard"
title     = "UUIDs"
author    = ["K. Davis"]
publisher = "IETF"
url       = "https://www.rfc-editor.org/rfc/rfc9562"
tier      = 1
stability = "pinned"

[[source]]
id              = "smith-2020"
type            = "article-journal"
title           = "A paper"
author          = ["A. Smith"]
container-title = "Journal"
volume          = "3"
issue           = "2"
page            = "10–20"
doi             = "10.1000/xyz"
tier            = 1
stability       = "pinned"
further_reading = true
'''


def problems(entry: dict) -> str:
    try:
        br.validate([entry])
    except br.SourceError as error:
        return str(error)
    return ""


class ValidateTests(unittest.TestCase):
    def test_valid_entries_pass(self):
        br.validate([PAGE_ENTRY, RFC_ENTRY])

    def test_missing_required_field(self):
        entry = dict(PAGE_ENTRY)
        del entry["tier"]
        self.assertIn("missing required field 'tier'", problems(entry))

    def test_unknown_field(self):
        self.assertIn("unknown field 'checked'", problems(dict(PAGE_ENTRY, checked="2026-11-19")))

    def test_key_pattern(self):
        for key in ("MS-Topic", "ms_topic", "ms--topic", "-ms", "ms-"):
            with self.subTest(key=key):
                self.assertIn("id must be", problems(dict(PAGE_ENTRY, id=key)))

    def test_duplicate_key(self):
        with self.assertRaisesRegex(br.SourceError, "ms-topic: duplicate id"):
            br.validate([PAGE_ENTRY, dict(PAGE_ENTRY)])

    def test_type_must_be_a_listed_csl_type(self):
        self.assertIn("type 'blog'", problems(dict(PAGE_ENTRY, type="blog")))

    def test_author_or_publisher(self):
        entry = dict(PAGE_ENTRY)
        del entry["publisher"]
        self.assertIn("needs 'author' or 'publisher'", problems(entry))

    def test_author_is_a_list_of_names(self):
        self.assertIn("author must be", problems(dict(RFC_ENTRY, author="K. Davis")))

    def test_tier_and_stability_values(self):
        self.assertIn("tier must be", problems(dict(PAGE_ENTRY, tier=4)))
        self.assertIn("stability must be", problems(dict(PAGE_ENTRY, stability="stable")))

    def test_living_source_needs_accessed(self):
        entry = dict(PAGE_ENTRY)
        del entry["accessed"]
        self.assertIn("a living source needs 'accessed'", problems(entry))

    def test_web_page_needs_url(self):
        entry = dict(PAGE_ENTRY)
        del entry["url"]
        self.assertIn("a webpage needs 'url'", problems(entry))

    def test_dates_are_iso_8601_strings(self):
        for value in ("19.11.2026", "2026-11-19T10:00", "2026/11"):
            with self.subTest(value=value):
                self.assertIn("accessed must be an ISO 8601 date", problems(dict(PAGE_ENTRY, accessed=value)))
        self.assertEqual("", problems(dict(RFC_ENTRY, issued="2024")))

    def test_urls_use_https(self):
        self.assertIn("url must start with https://", problems(dict(PAGE_ENTRY, url="http://example.org")))

    def test_every_problem_is_reported(self):
        text = problems({"id": "x", "type": "webpage", "title": "t", "tier": 1, "stability": "living"})
        for expected in ("needs 'author' or 'publisher'", "needs 'accessed'", "needs 'url'"):
            self.assertIn(expected, text)


class CitationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.docs = pathlib.Path(self.temp.name) / "docs"
        (self.docs / "references").mkdir(parents=True)
        (self.docs / "domain").mkdir()
        (self.docs / "references" / "sources.toml").write_text(SOURCES, encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def write(self, relative: str, text: str) -> pathlib.Path:
        path = self.docs / relative
        path.write_text(textwrap.dedent(text), encoding="utf-8")
        return path

    def run_quietly(self, check: bool) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = br.run(self.docs, check=check)
        return code, output.getvalue()

    def test_citations_are_found_on_pages_but_not_in_code(self):
        self.write("domain/page.md", """\
            # A page

            UUIDs are time-ordered.[^rfc-9562]

            ```markdown
            [^smith-2020]: [Smith](../references/index.md#smith-2020)
            ```

            An inline example: `../references/index.md#smith-2020`.

            [^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562), section 5.7.
            """)
        self.write("index.md", "# Home\n\nSee [the standard](references/index.md#rfc-9562).\n")
        cited = br.citations(self.docs, self.docs / "references" / "index.md")
        self.assertEqual({"rfc-9562"}, set(cited))
        self.assertEqual([self.docs / "domain" / "page.md", self.docs / "index.md"], sorted(cited["rfc-9562"]))

    def test_render_has_an_anchor_per_key_groups_and_cited_in(self):
        self.write("domain/page.md", "# A page\n\nText.[^rfc-9562]\n\n[^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562).\n")
        page = self.docs / "references" / "index.md"
        text = br.render(br.load(self.docs / "references" / "sources.toml"), br.citations(self.docs, page), page)
        self.assertIn('<a id="rfc-9562"></a>K. Davis. *UUIDs*. IETF.', text)
        self.assertIn('<a id="smith-2020"></a>A. Smith. *A paper*. Journal 3(2), pp. 10–20. [doi:10.1000/xyz](https://doi.org/10.1000/xyz).', text)
        self.assertLess(text.index("## Standards and specifications"), text.index("## Books, papers and reports"))
        self.assertNotIn("## Documentation and web pages", text)
        self.assertIn("cited in [A page](../domain/page.md)", text)
        self.assertIn("`smith-2020` · tier 1 · pinned · further reading", text)

    def test_check_passes_after_writing_and_fails_when_out_of_date(self):
        self.assertEqual(1, self.run_quietly(check=True)[0])
        self.assertEqual(0, self.run_quietly(check=False)[0])
        self.assertEqual(0, self.run_quietly(check=True)[0])
        page = self.docs / "references" / "index.md"
        page.write_text(page.read_text(encoding="utf-8").replace("\n", "\r\n"), encoding="utf-8", newline="")
        self.assertEqual(0, self.run_quietly(check=True)[0], "CRLF line endings of a Windows working copy are not a difference")
        self.write("domain/new.md", "# New\n\nText.[^rfc-9562]\n\n[^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562).\n")
        code, output = self.run_quietly(check=True)
        self.assertEqual(1, code)
        self.assertIn("out of date", output)

    def test_invalid_sources_fail(self):
        (self.docs / "references" / "sources.toml").write_text(SOURCES.replace('tier      = 1\n', '', 1), encoding="utf-8")
        code, output = self.run_quietly(check=False)
        self.assertEqual(1, code)
        self.assertIn("rfc-9562: missing required field 'tier'", output)


class RepositoryTests(unittest.TestCase):
    def test_the_bibliography_of_the_repository_is_valid_and_up_to_date(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = br.run(br.DOCS, check=True)
        self.assertEqual(0, code, output.getvalue())


if __name__ == "__main__":
    unittest.main()
