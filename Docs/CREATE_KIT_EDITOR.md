# Create Kit editor

Create Kit is BagLog's composer-first local kit editor. It is presented for a
new kit or an existing draft; published kits remain read-only.

## Interaction contract

- A first-time user creates one local display name and handle inside the sheet.
- Return in the title moves focus to the item composer. Return in the composer
  trims and inserts every completed line, scrolls the new card into view, and
  keeps the keyboard focused.
- One item expands at a time. Stable item and link identifiers define the
  Previous, Next, and Done keyboard route.
- Items and photos support native drag/drop, visible drop feedback, menu-based
  movement, and accessibility reorder actions.
- System springs animate insertion, expansion, deletion, lift, and movement.
  Reduce Motion uses short fades or non-travelling transitions.
- Liquid Glass is confined to the bottom composer. Data cards use opaque system
  backgrounds for legibility over the neutral mesh canvas.

## Save state machine

The `@MainActor @Observable` editor store owns value-type drafts. Persistence
does not begin until a local profile exists and the kit title is valid.

Text changes restart a 600 ms debounce. Structural changes request a save
immediately. A save already in progress is never cancelled: revision tracking
coalesces any edits made during that operation into one follow-up save. A
completion can show `Saved` only when its revision still matches the editor.

Invalid current input never overwrites the last valid snapshot. The editor
keeps the invalid fields visible with an actionable explanation. Closing first
flushes valid changes; invalid or failed pending work offers Keep Editing,
Retry Saving, or Discard Unsaved Changes.

## Media ownership

PhotosPicker transfers selected image files without broad library access.
`FileMediaStore` copies each image to Application Support and creates a
downsampled thumbnail. The draft retains ordered asset identifiers, filenames,
and thumbnails; index zero is the cover and the gallery is capped at three.

The store tracks committed filenames separately from staged filenames:

- a staged file is removed when the user discards it or closes with Discard;
- a committed file is retained until a save without that asset succeeds;
- a failed database save does not delete a file still referenced by the last
  valid database snapshot.

## Publication and navigation

Publishing requires a valid title, at least one valid item, positive
quantities, and complete HTTPS links. The confirmation states that publication
is local to this device. Publication waits for any active draft save, re-reads
the resulting draft identifier, saves public/published state, then dismisses.

The router holds a pending typed My Kits detail route. Sheet dismissal applies
that route and refreshes My Kits, avoiding delay-based navigation. Draft rows
reopen Create Kit; published rows open read-only detail with gallery, item
category, and links.
