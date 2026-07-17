# Create Kit Topic Picker — Design QA

**Comparison target**

- Source visual truth, fixed menu: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-menu-before.png`
- Source visual truth, compact control: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-button-before.png`
- Implementation hero: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-hero-final-full.jpg`
- Implementation sheet: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-sheet-final.jpg`
- Full-view comparison evidence: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-comparison-final.jpg`
- Focused-region evidence: the comparison board includes readable, normalized crops of both the original and final topic controls. A second crop is unnecessary because the only small control is already isolated at the bottom of the board.
- Viewport: iPhone 17 Pro simulator, iOS 26.2, 368 × 800 point implementation captures. The source menu is a user-provided focused crop, so the board normalizes scale without claiming pixel-identical framing.
- State: light appearance, new draft, `Other` selected, topic sheet presented at its large detent.

**Findings**

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: the compact control, navigation title, search field, result count, and rows use semantic system styles. Topic names use headline weight, remain single-line for fast scanning, and inherit Dynamic Type rather than fixed font sizes.
- Spacing and layout rhythm: the hero keeps a 44-point compact disclosure instead of expanding a tall menu over the editor. The sheet provides a stable header, persistent search field, and regular card rhythm. The current topic is pinned first at rest, eliminating the clipped first-row state seen during iteration.
- Colors and visual tokens: warm neutral surfaces continue the Create Kit canvas; orange is reserved for topic glyphs and the selected state. The selected row remains identifiable by both its filled icon tile and checkmark.
- Image quality and asset fidelity: no raster assets were required. All topic and control glyphs use coherent SF Symbols; no emoji, handcrafted SVG, placeholder art, or code-drawn approximations were introduced.
- Copy and content: `Choose a topic`, `Search topics`, and the live singular/plural result count are direct and task-oriented. Titles and search keywords are supplied by the topic catalog rather than embedded into row UI.
- Accessibility and resilience: close, clear-search, topic, and hero controls have text labels; interactive targets meet the 44-point minimum; selected state is exposed through accessibility value and not color alone. The custom search field remains above list hit-testing, and the focused UI test proves filtering, clearing, and selecting work.
- Backend readiness: topic identity is a stable raw string rather than a closed enum. The editor accepts an injected catalog, unknown persisted identifiers survive Codable and SwiftData round trips, and a missing current topic is inserted into the sheet so it never disappears while catalogs refresh.

**Comparison history**

- Iteration 1 — P2: the fixed picker menu grew taller with every bundled topic, obscured the editor, and offered no search path for a backend-sized catalog. Fix: replace it with a compact hero disclosure and a dedicated large sheet with custom searchable rows and live result count.
- Iteration 2 — P2: the first sheet pass used navigation search and auto-scrolled to the last selected row; the search surface obscured the first visible row. Fix: move search into a persistent custom field and pin the selected topic first while preserving catalog order for the remaining results.
- Iteration 3 — P2: an unknown persisted backend topic rendered on the hero but was absent from a bundled-only picker. Fix: inject the catalog from `CreateKitView` and prepend a fallback current topic when its identifier is missing.
- Post-fix visual evidence: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/topic-comparison-final.jpg` shows the compact disclosure and the unobscured searchable sheet with `Other` selected first.

**Primary interactions tested**

- Open the topic picker from the hero in a separate sheet.
- Focus search, enter `cam`, verify one Camera result, clear search, and restore all topics.
- Select Travel and verify the hero control updates to `Topic, Travel`.
- Encode/decode an arbitrary `winter-bike-commute` identifier and preserve it through draft command mapping.
- Merge an unknown current topic into the injected catalog without duplicates.
- Tuist workspace generation succeeded; the simulator app built and launched successfully.
- Full simulator suite: 19 tests passed, 0 failed, 0 skipped. The final focused topic UI regression test also passed after the search accessibility correction.

**Implementation Checklist**

- [x] Replace the growing menu with a dedicated searchable sheet.
- [x] Pin the current selection and keep remaining catalog order stable.
- [x] Make the catalog injectable for backend data.
- [x] Preserve and surface unknown remote identifiers.
- [x] Cover search, clear, selection, persistence, and dynamic-catalog behavior.
- [x] Build, run, capture, and compare the final states.

**Follow-up Polish**

- No P3 visual work is required for this scope. Loading, retry, and pagination states should be designed when the backend contract is introduced.

final result: passed
