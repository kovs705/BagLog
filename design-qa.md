# Create Kit — Design QA

**Comparison target**

- Overall visual truth: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/source-option-1.png`
- User-reported row state: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-cells-before.png`
- User-reported inline editor state: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-inline-editor-before.png`
- Implementation row screenshot: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-cells-final.jpg`
- Implementation sheet screenshot: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-sheet-final.jpg`
- Viewport: iPhone 17 Pro simulator, iOS 26.2, 368 × 800 point implementation captures. The user screenshots are focused crops from the same compact phone layout.
- State: light appearance, populated draft, item list at rest and item editor presented.
- Full-view and focused-region comparison evidence: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-cells-comparison-final.jpg`

The comparison board is already cropped to the two important regions—item rows and the item editor—at readable size, so a second focused crop is unnecessary. The automated fixture contains more items than the user capture, but count and sample-data differences do not affect the row or sheet comparison.

**Findings**

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: the rows use Dynamic Type system headline/subheadline styles, preserve two title lines when needed, and replace the competing blue `Item actions` text with a quiet icon-only menu that retains an accessible text label. Sheet hierarchy is clear from navigation title to section heading to editable content.
- Spacing and layout rhythm: compact natural-height rows replace the oversized cards. The 44-point reorder and menu targets remain intact, titles have more usable width, and details no longer expand inside the parent scroll. The large sheet gives the form and keyboard independent vertical space.
- Colors and visual tokens: the warm paper surface, regular material rows, orange item glyphs, secondary metadata, and neutral action button continue the selected Create Kit art direction without adding a competing palette.
- Image quality and asset fidelity: this revision has no raster image assets. It uses SF Symbols for shipping, category, reorder, disclosure, and actions; no emoji, placeholders, or handcrafted approximations were introduced.
- Copy and content: `Add details` is shorter and clearer than `Tap for details`; `Pack the details` and its supporting line describe the packing task rather than the design rationale. Item count, quantity, category, brand/model, link count, and essential state remain data-driven.
- Accessibility: every row and menu keeps a minimum 44-point target, the menu and image-only actions retain text labels, row editing has an explicit sheet-opening hint, reorder actions remain available to assistive technologies, and the sheet owns a separate focus order. Presenting the sheet now clears parent composer focus so the keyboard toolbar cannot leak behind the modal.

**Comparison history**

- Iteration 1 — P2: each list row was oversized; long titles, an expansion chevron, and visible `Item actions` text competed horizontally. Expanding a row inserted a near-screen-height form into the parent scroll. Fix: replaced the row with a compact manifest cell and moved all item fields to an item-driven sheet.
- Iteration 2 — P2: the first sheet pass left parent composer focus active, allowing its keyboard toolbar to remain after dismissal. It also used design-rationale helper copy and retained a blue menu glyph. Fix: clear parent focus before presentation, scope item focus to the sheet, replace helper copy with task-oriented language, and tint the menu neutrally.
- Post-fix evidence: `/Users/kovs/.codex/visualizations/2026/07/16/019f6d4e-d415-7d81-8123-4af778f0ecce/baglog-create-kit-design-qa/item-cells-comparison-final.jpg` shows compact rows and the dedicated large sheet with no inline expansion.

**Primary interactions tested**

- Add multiple items with Return without losing composer focus or auto-presenting the editor.
- Tap a compact row, present the separate item sheet, and dismiss it with Done.
- Edit item fields through the existing live autosave bindings.
- Preserve drag/drop, Move up, Move down, Delete, essential, quantity, category suggestions, notes, and links.
- Tuist workspace generation succeeded; simulator build succeeded without warnings.
- Full suite: 17 tests passed. Dedicated UI suite: 3 tests passed, including the new separate-sheet regression test. The final focus cleanup was rebuilt and the focused sheet UI test passed again.
- Native simulator review found no crash, clipped primary action, or interaction blocker in the tested states.

**Implementation Checklist**

- [x] Replace inline disclosure with an item-driven sheet.
- [x] Redesign item cells for compact scanning and long titles.
- [x] Preserve reorder, action menu, deletion, and autosave behavior.
- [x] Separate parent and item-editor keyboard focus orders.
- [x] Add a UI regression test for item-sheet presentation and dismissal.
- [x] Build, test, capture, and compare both relevant states.

**Follow-up Polish**

- Optional P3: add item thumbnails later if the product model gains per-item photography; the current data model has no such asset.

final result: passed
