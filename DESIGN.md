---
version: alpha
name: "codex-profiles"
description: "An editorial command-surface identity for switching isolated Codex profiles without token swapping."
colors:
  primary: "#000000"
  ink: "#000000"
  paper: "#FFFFFF"
  neutral: "#F1F1F1"
  muted: "#666666"
  rule: "#000000"
  personal: "#FF7373"
  work: "#9CD5FE"
  school: "#9BF396"
  client: "#FFD0B8"
  focus: "#2F6BFF"
typography:
  display:
    fontFamily: "Schibsted Grotesk, Arial Black, sans-serif"
  body:
    fontFamily: "Hanken Grotesk, Arial, sans-serif"
  utility:
    fontFamily: "JetBrains Mono, SFMono-Regular, Menlo, monospace"
rounded:
  DEFAULT: "0rem"
  control: "0rem"
  media: "0.125rem"
  status: "999px"
spacing:
  gutter: "clamp(1.25rem, 4vw, 4rem)"
  section: "clamp(4.5rem, 9vw, 9rem)"
  page-max: "95rem"
components:
  top-nav: {}
  button: {}
  command-deck: {}
  signal-rail: {}
  isolation-graph: {}
  feature-ledger: {}
  specs-table: {}
  faq-row: {}
---

# codex-profiles Design System

## Overview

### Creative North Star

The public site should feel like a compact hardware operator manual made for a command-line tool: decisive grotesk headlines, mono annotations, hairline rules, physical control surfaces, and status lights that carry real information. The Work Louder collaboration page is a rhythm reference, not a template or brand source.

### Product context and register

- **Audience and primary job:** Developers who move between personal, work, school, and client Codex accounts and need to understand, install, and trust profile isolation quickly.
- **Target market(s) and evidence:** Global developer audience; the CLI and documentation are English-first and support macOS and Linux.
- **Locale(s) and language policy:** English (`en`) is the maintained site language. Technical tokens, commands, paths, and product names remain verbatim.
- **Usage scene:** Laptop-first discovery and installation, with the same core information usable on a phone. Low density above the fold; precise technical density in diagrams and specifications.
- **Register:** Brand site with product-documentation proof.
- **Memorable signature:** A four-channel profile signal system: personal coral, work blue, school green, client peach. Color always identifies a profile or isolation path.
- **Restraint:** Body copy, commands, facts, safety boundaries, and FAQ answers stay plain, direct, and high contrast.
- **Anti-references:** No glossy SaaS card wall, pastel gradient haze, floating dashboard mockups, generic icon grid, or ornamental RGB effects detached from profile state.
- **Token ownership/runtime mapping:** `docs/index.html` is the canonical runtime source. This file mirrors its accepted `:root` custom properties and explains their use; changes to durable tokens update both files in one changeset.

## Colors

True white and black carry the editorial structure. `neutral` is reserved for quiet code/table surfaces. Profile accents are semantic: `personal`, `work`, `school`, and `client` label the same identity consistently in the command deck, signal rail, and isolation diagram. `focus` exists only for a clearly visible keyboard focus ring. Do not use profile colors as arbitrary section decoration.

## Typography

Schibsted Grotesk is the display face: tight tracking, heavy weight, and responsive sizes up to poster scale. Hanken Grotesk handles explanations and FAQ copy. JetBrains Mono owns commands, paths, status labels, navigation utilities, and table labels. Sentence case is the default; uppercase is reserved for compact utility metadata. Body copy should stay near 17px with comfortable line height and a readable measure.

## Layout

The page uses a full-width band model with a maximum inner width of 95rem. Major sections alternate open white space with black, blue, peach, or neutral bands. Thin black rules establish alignment and sequence. Desktop compositions may use asymmetrical 5/7 or 4/8 columns; mobile collapses to a single flow without hiding copy or actions. Media reserves its aspect ratio, tables own horizontal overflow, and sticky navigation must not obscure focus targets.

## Elevation & Depth

Hierarchy comes from scale, contrast, rules, and color fields. Flat surfaces are the default. The command deck and real desktop screenshot may use one restrained physical shadow; cards, tables, FAQ rows, and section wrappers do not float.

## Shapes

Edges are square. Buttons, terminal surfaces, diagram nodes, and tables use zero or near-zero radius. Circular status lamps are the one deliberate exception. Icons use simple 1.5px–2px strokes and remain optically aligned with text.

## Components

### Foundational visual states

Interactive elements have a visible default outline or boundary, an inverted or profile-accent hover, a 3px blue focus-visible ring, and a small pressed translation. Disabled states reduce contrast without removing labels. Content appears immediately when reduced motion is requested.

### Buttons and actions

Primary actions are black rectangles with white text. Secondary actions are white with a black 1px rule. Labels use JetBrains Mono and keep a stable minimum height of 48px. Arrow icons remain code-native SVG or text glyphs only when the typographic treatment intentionally calls for them.

### Navigation and data display

The top navigation is a quiet white rail separated by a black rule. The profile signal rail repeats the four semantic status colors. Tables look like specification sheets: mono row labels, plain values, horizontal rules, no rounded wrapper.

### Forms and overlays

The public site has no product forms or modal flows. Graph tooltips are high-contrast black utility surfaces and must not contain the only copy of important information.

### Iconography

Use small custom line icons or existing inline SVGs with square geometry. Icons support labels; they do not replace them. Profile identity is communicated by labeled status lamps, not color alone.

### Motion

One orchestrated load/reveal sequence and restrained hover/graph motion are allowed. Content reveals last about 550ms with `cubic-bezier(0.22, 1, 0.36, 1)`. All animation and smooth scrolling stop under `prefers-reduced-motion: reduce`.

### Content and data visualization

Voice is direct, factual, and command-oriented. State security boundaries exactly: the tool isolates Codex local state through `CODEX_HOME`; operating-system credentials remain shared. Diagrams retain text labels and readable fallbacks so color and interactivity are never the only explanation.

## Do's and Don'ts

- **Do:** Use oversized type and full-width bands to make the small CLI feel tangible.
- **Do:** Keep each profile color bound to the same named profile everywhere.
- **Don't:** copy OpenAI logos, product imagery, or branded wordmarks from the reference.
- **Don't:** introduce rounded card grids, decorative gradients, hidden scrollbars, or color-only status cues.
