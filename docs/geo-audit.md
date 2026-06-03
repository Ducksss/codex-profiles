# GEO Audit for codex-profiles

This audit maps the public documentation layer to the GEO checklist supplied
for the project. The implementation target is a GitHub Pages site served from
`docs/`.

## Technical AI Readiness

| Check | Status | Implementation |
| --- | --- | --- |
| AI bots allowed in robots.txt | Implemented | `docs/robots.txt` uses `User-agent: *` and `Allow: /`. |
| Priority URLs return 200 | Implemented after Pages deployment | `docs/index.html`, `docs/llms.txt`, and `docs/sitemap.xml` are static files. |
| Pages are indexable | Implemented | `docs/index.html` uses `index,follow` and does not contain `noindex`. |
| Canonicals are correct | Implemented | `docs/index.html` canonicalizes to `https://ducksss.github.io/codex-profiles/`. |
| Snippet settings allow extraction | Implemented | Robots meta uses unrestricted snippet, image, and video preview directives. |
| XML sitemap is clean | Implemented | `docs/sitemap.xml` lists the canonical page and LLM summary file. |

## Structured Data and Machine Understanding

| Check | Status | Implementation |
| --- | --- | --- |
| Organization schema present | Implemented | JSON-LD includes the project publisher and official sameAs links. |
| Product schema added where relevant | Implemented | JSON-LD includes SoftwareApplication with repository, install, license, version, platform, features, and free offer data. |
| FAQ schema only when visible | Implemented | Every FAQPage question and answer is visible on `docs/index.html`. |
| Schema matches visible content | Implemented | The GEO test validates FAQ question and answer text against visible HTML. |
| Article schema correct on content pages | Not applicable | The current Pages site is a product page, not a blog or article section. |
| Local schema added where relevant | Not applicable | codex-profiles is a software project with no public local business location. |
| Schema validation is logged | Implemented | `node test/geo-site-test.mjs` validates JSON-LD parseability and required fields. |

## Content Structure and Citation Readiness

| Check | Status | Implementation |
| --- | --- | --- |
| Question-based headings | Implemented | FAQ uses direct question headings. |
| Direct answer in first 1-3 sentences | Implemented | The first content section defines the product and isolation boundary immediately. |
| Bullets, tables, and commands | Implemented | The page includes feature cards, install commands, and a citation-ready facts table. |
| Short paragraphs | Implemented | Sections use concise, extractable paragraphs. |
| Facts and stats current | Implemented | Version, license, package name, platforms, and URLs match repository metadata as of 2026-06-03. |
| Clear About content | Implemented | Trust and methodology section states what the tool is, who maintains it, and what it does not claim. |

## Entity, Trust, and Brand Authority

| Check | Status | Implementation |
| --- | --- | --- |
| Consistent project name | Implemented | Page, schema, package metadata, and llms.txt use codex-profiles and codex-profile consistently. |
| Consistent contact paths | Implemented | Official repository, issues, discussion, npm, license, and security links are present. |
| sameAs links to official profiles | Implemented | Organization schema points to GitHub and npm. |
| Real policies where advice is given | Implemented | Security boundaries link to the repository security policy and README security model. |
| Compare proof vs project pages | Implemented | The public page exposes concrete commands, platform limits, and non-claims rather than broad marketing language. |

## Measurement, Testing, and Outcomes

| Check | Status | Implementation |
| --- | --- | --- |
| Define target prompt set | Implemented | `docs/geo-measurement.md` contains reusable prompts. |
| Retest prompts after changes | Implemented | Measurement plan requires baseline and post-change runs. |
| Track citation count and position | Implemented | Measurement plan includes citation and position columns. |
| Track cited pages over time | Implemented | Measurement plan records exact cited URLs per prompt. |
| Capture before/after screenshots | Implemented | Measurement plan includes screenshot evidence paths. |
| Report KPIs | Implemented | Measurement plan defines visibility, citation, accuracy, and lead/conversion KPIs. |

## Validation Commands

```sh
node test/geo-site-test.mjs
make test
```
