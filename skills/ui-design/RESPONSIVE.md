# Responsive and touch

## How people hold phones

The popular thumb-zone heat map is wrong. Hoober's field studies: 75% tap with one thumb but fewer than half hold one-handed, grips change constantly, and people look at and tap the **centre** most accurately. Centre targets can be ~7mm; corner targets need ~12mm. The top-corner Back button is often the most-used control.

- Make edge and corner targets larger rather than moving everything to the bottom.
- Bottom sheets don't automatically improve reach; give each one a visible close button, since users don't know to swipe.
- Every gesture (swipe, pinch, long-press) has a visible button equivalent.
- Mobile primary navigation: a 3–5 item tab bar with icon **and** label; secondary items under "More".

## Mobile browser mechanics

- `100vh` is the large viewport and overflows while toolbars show. Use `100svh` for stable full-height layouts, `100dvh` to track the toolbars.
- Viewport meta: `width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content`. `viewport-fit=cover` makes `env(safe-area-inset-*)` non-zero on iOS; pad fixed bars with it. `interactive-widget` makes Android shrink the layout when the keyboard opens.
- Inputs `font-size: max(16px, 1rem)` so iOS doesn't zoom. Keep pinch-zoom enabled: `user-scalable=no` breaks WCAG 1.4.4.
- Sticky bars stay short; together they leave most of the screen for content (convention).
- Gate hover affordances with `@media (hover: hover) and (pointer: fine)`. Viewport width says nothing about touch.

## Strategy

- Breakpoints sit where the content breaks, in `em`, not at device widths.
- `@container` size queries (Baseline since Aug 2025) for components placed in more than one slot: cards, list rows, chart cards. `@media` for the shell, navigation pattern and `prefers-*`.
- Intrinsic grids: `grid-template-columns: repeat(auto-fit, minmax(min(16rem, 100%), 1fr))`.
- Logical properties throughout (`margin-inline-start`, `padding-block`, `inset-inline-end`) so RTL mirrors for free.
- Responsive images: `srcset` + `sizes`, explicit `width`/`height`, never `loading="lazy"` on the largest above-the-fold image.

## Wide tables on narrow screens

WCAG reflow exempts data tables, so two layouts are valid:

- **Scroll wrapper** (default when users compare across rows): a focusable `overflow-x: auto` region with the first column `position: sticky`.
- **Row cards** (when each row is read on its own): identifier and status first line, key figures second, actions in one overflow button.

Either way, the rank-1 columns stay in view.

## Zoom and reflow

Check at 320 CSS px width (400% zoom) and at 200% text size: no two-dimensional scrolling, nothing clipped, nothing overlapping. Text survives user spacing overrides (line-height 1.5, paragraph spacing 2em, letter-spacing 0.12em, word-spacing 0.16em).
