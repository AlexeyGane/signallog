"""Tests of eng/docs/check_references.py (ADR 0021). Run from the repository root:

    python -m unittest discover -s eng/docs/tests -v
"""

import pathlib
import sys
import tempfile
import textwrap
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_references as cr  # noqa: E402

SOURCES = '''
[[source]]
id        = "rfc-9562"
type      = "standard"
title     = "UUIDs"
publisher = "IETF"
tier      = 1
stability = "pinned"

[[source]]
id        = "steele-2014"
type      = "paper-conference"
title     = "Fast Splittable Pseudorandom Number Generators"
author    = ["Guy L. Steele Jr."]
tier      = 1
stability = "pinned"
'''

CITING_PAGE = """\
# Identifiers

UUIDs are time-ordered.[^rfc-9562] The generator mixes bits.[^steele-2014]

[^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562), section 5.7.
[^steele-2014]: [Steele 2014](../references/index.md#steele-2014).
"""


class RepositoryFixture(unittest.TestCase):
    """A small repository: docs, bibliography, concepts page, requirements, one ADR and code."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.write("docs/references/sources.toml", SOURCES)
        self.write("docs/references/index.md", '# Bibliography\n\n- <a id="rfc-9562"></a>generated\n')
        self.write("docs/domain/identifiers.md", CITING_PAGE)
        self.write("docs/adr/0012-message-contract.md", "# 0012\n")
        self.write("docs/requirements/nfr.md", "# NFRs\n\n#### NFR-SEC-03 — Supply chain\n")
        self.write("docs/requirements/business-rules.md", "# Rules\n\n#### BR-PRICE-03 — Source and age\n")
        self.write("docs/domain/generator.md", '# Generator\n\n<a id="two-layers"></a>\n## 6. Two layers\n')
        self.write(cr.CONCEPTS_PAGE, '# Concepts\n\n| <a id="uuidv7"></a>**UUIDv7** | ... |\n| <a id="c4"></a>**C4** | ... |\n')
        self.write("docs/domain/uses-concept.md", "# Uses\n\nA [UUIDv7](../standards/concepts-and-sources.md#uuidv7) key.\n")
        self.write(cr.LEGACY_LIST, "# legacy\n")

    def tearDown(self):
        self.temp.cleanup()

    def write(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(text), encoding="utf-8")

    def legacy(self, *paths: str) -> None:
        self.write(cr.LEGACY_LIST, "# legacy\n" + "".join(f"{p}\n" for p in paths))

    def findings(self, kind: str | None = None) -> list:
        return [f for f in cr.check(self.root) if kind is None or f.kind == kind]


class PageTests(RepositoryFixture):
    def test_a_clean_repository_has_only_the_expected_unused_concept(self):
        self.assertEqual(["concept 'c4' is linked from no other page"], [f.message for f in self.findings()])

    def test_unused_and_undefined_footnotes(self):
        self.write("docs/domain/page.md", "# P\n\nText.[^used-only]\n\n[^defined-only]: [X](../references/index.md#rfc-9562).\n")
        messages = sorted(f.message for f in self.findings("footnote"))
        self.assertEqual(["footnote [^defined-only] is defined but not used", "footnote [^used-only] is used but not defined"], messages)
        self.assertEqual({"docs/domain/page.md"}, {f.path for f in self.findings("footnote")})

    def test_external_url_on_a_page_is_an_error_with_its_line(self):
        self.write("docs/domain/page.md", "# P\n\nSee https://example.org/spec.\n")
        [finding] = self.findings("external-url")
        self.assertEqual(("docs/domain/page.md", 3, "error"), (finding.path, finding.line, finding.level))
        self.assertIn("https://example.org/spec:", finding.message)

    def test_own_links_code_and_comments_are_not_external_urls(self):
        self.write("docs/domain/page.md", textwrap.dedent("""\
            # P

            The [repository](https://github.com/AlexeyGane/signallog/tree/main/src) and the [site](https://alexeygane.github.io/signallog/).
            Preview at `http://localhost:8000` or in code:

            ```toml
            url = "https://www.rfc-editor.org/rfc/rfc9562"
            ```

            <!-- https://example.org/in-a-comment -->
            """))
        self.assertEqual([], self.findings("external-url"))

    def test_findings_on_a_legacy_page_are_warnings(self):
        self.write("docs/domain/page.md", "# P\n\nSee https://example.org/spec.\n")
        self.legacy("docs/domain/page.md")
        [finding] = self.findings("external-url")
        self.assertEqual("warning", finding.level)

    def test_a_missing_path_in_the_legacy_list_is_reported(self):
        self.legacy("docs/domain/gone.md")
        [finding] = self.findings("legacy-list")
        self.assertEqual((cr.LEGACY_LIST, 2), (finding.path, finding.line))


class BibliographyAndConceptTests(RepositoryFixture):
    def test_an_entry_cited_nowhere_is_an_error_unless_further_reading(self):
        self.write("docs/domain/identifiers.md", CITING_PAGE.replace(" The generator mixes bits.[^steele-2014]", "").split("[^steele-2014]:")[0])
        [finding] = self.findings("uncited-source")
        self.assertEqual((cr.SOURCES_FILE, 11, "error"), (finding.path, finding.line, finding.level))
        self.assertIn("steele-2014", finding.message)
        self.write("docs/references/sources.toml", SOURCES + 'further_reading = true\n')
        self.assertEqual([], self.findings("uncited-source"))

    def test_unused_concept_follows_the_legacy_state_of_the_concepts_page(self):
        [finding] = self.findings("unused-concept")
        self.assertEqual((cr.CONCEPTS_PAGE, 4, "error"), (finding.path, finding.line, finding.level))
        self.legacy(cr.CONCEPTS_PAGE)
        self.assertEqual("warning", self.findings("unused-concept")[0].level)


class MirrorTests(RepositoryFixture):
    def test_a_mirror_with_other_keys_or_anchors_is_reported(self):
        self.write("docs/fun-facts/index.md", '# Fun facts\n\n<a id="uuid"></a>\n## UUID\n\nText.[^rfc-9562]\n\n[^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562).\n')
        self.write("docs/fun-facts/ru.md", '# Факты\n\n<a id="uuid-v7"></a>\n## UUID\n\nТекст.\n')
        messages = [f.message for f in self.findings("mirror")]
        self.assertEqual(3, len(messages), messages)
        self.assertTrue(any("footnote keys of docs/fun-facts/index.md missing here: rfc-9562" in m for m in messages))
        self.assertTrue(any("explicit anchors not in docs/fun-facts/index.md: uuid-v7" in m for m in messages))

    def test_a_matching_mirror_is_clean(self):
        page = '<a id="uuid"></a>\n## UUID\n\nText.[^rfc-9562]\n\n[^rfc-9562]: [RFC 9562](../references/index.md#rfc-9562), section 5.7.\n'
        self.write("docs/fun-facts/index.md", "# Fun facts\n\n" + page)
        self.write("docs/fun-facts/ru.md", "# Факты\n\n" + page.replace("section", "раздел").replace("Text", "Текст"))
        self.assertEqual([], self.findings("mirror"))


class CodeTests(RepositoryFixture):
    def code(self, text: str, name: str = "src/App/Replay.cs") -> list:
        self.write(name, text)
        return [f for f in self.findings() if f.kind in ("code-link", "code-id")]

    def test_valid_links_ids_and_keys_in_code_pass(self):
        self.assertEqual([], self.code(textwrap.dedent("""\
            /// <summary>SplitMix64 finalizer [steele-2014]; ADR 0012, NFR-SEC-03, BR-PRICE-03.</summary>
            /// <seealso href="https://alexeygane.github.io/signallog/domain/generator/#two-layers"/>
            // See https://github.com/AlexeyGane/signallog/blob/main/docs/domain/generator.md
            int[] values = new int[3]; var digit = "[0-9]"; var hex = "[a-f0-9]";
            """)))

    def test_a_link_to_a_missing_page_or_a_generated_anchor_fails(self):
        findings = self.code(textwrap.dedent("""\
            /// <seealso href="https://alexeygane.github.io/signallog/domain/missing/"/>
            /// <seealso href="https://alexeygane.github.io/signallog/domain/generator/#6-two-layers"/>
            """))
        self.assertEqual([(1, "code-link"), (2, "code-link")], [(f.line, f.kind) for f in findings])
        self.assertIn("no such page", findings[0].message)
        self.assertIn("'6-two-layers' is not an explicit anchor", findings[1].message)
        self.assertTrue(all(f.level == "error" for f in findings))

    def test_links_from_configuration_are_checked(self):
        findings = self.code("@{ Links = @('https://alexeygane.github.io/signallog/note/', 'https://github.com/AlexeyGane/signallog/blob/main/docs/gone.md') }\n",
                             "eng/azure-devops/boards.settings.psd1")
        self.assertEqual(2, len(findings))
        self.assertIn("note/: no such page", findings[0].message)
        self.assertIn("docs/gone.md does not exist", findings[1].message)

    def test_unknown_ids_and_source_keys_fail(self):
        findings = self.code("// ADR 0099, ADR-0098, NFR-SEC-99, BR-PRICE-99, key [knuth-1997]\n")
        self.assertEqual(
            ["ADR 0099 does not exist", "ADR-0098 does not exist", "BR-PRICE-99 is not in docs/requirements/business-rules.md",
             "NFR-SEC-99 is not in docs/requirements/nfr.md", "source key [knuth-1997] is not in docs/references/sources.toml"],
            sorted(f.message for f in findings))

    def test_source_keys_outside_comments_and_build_output_are_ignored(self):
        self.assertEqual([], self.code('var tag = "[knuth-1997]";\n'))
        self.assertEqual([], self.code("// ADR 0099\n", "src/App/bin/Debug/Generated.cs"))


class RepositoryTests(unittest.TestCase):
    def test_the_repository_has_no_errors(self):
        errors = [str(f) for f in cr.check(cr.ROOT) if not f.legacy]
        self.assertEqual([], errors)


if __name__ == "__main__":
    unittest.main()
