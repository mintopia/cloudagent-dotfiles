---
name: ui-design
description: Concrete UI rules with numbers for building or reviewing dashboards, app screens and landing pages.
disable-model-invocation: true
---

# UI design

Rules distilled from working product designers, WCAG 2.2 and UX research, with concrete values. Where they conflict with your default UI instincts, they win.

## Steps

1. **Classify the surface and load its files.** Product UI (dashboard, app screen, settings, admin, mobile app) → [PRODUCT-UI.md](PRODUCT-UI.md). Marketing (landing page, homepage, pricing, 404) → [MARKETING.md](MARKETING.md). Judge each page by its own surface. Also read, when the screen has them:
   - forms or text inputs → [FORMS.md](FORMS.md)
   - custom widgets (dialog, menu, tabs, combobox, grid, drag-and-drop, live updates) → [WIDGETS.md](WIDGETS.md)
   - touch-first screens or layouts that change shape across sizes → [RESPONSIVE.md](RESPONSIVE.md)
   - more than one language, or right-to-left scripts → [I18N.md](I18N.md)
   - a critique, audit or review of existing UI → [REVIEW.md](REVIEW.md)
2. **Inventory the content.** List every piece of data or message the screen shows. Give each a _shape_ (enum, number, time series, actor, long text, image, action) and a _rank_ (1 = the reason the screen exists). Done when every item has both.
3. **Set tokens before markup.** Define spacing, type scale, neutrals, accent ramp, semantic colours and shadows as CSS custom properties. Take colour values from [COLOR.md](COLOR.md); read it whenever you pick or change a colour, add dark mode, or theme. Done when every colour, size and gap in component styles references a token.
4. **Lay out by rank** using the reference below, in semantic HTML from the start ([Accessibility baseline](#accessibility-baseline)).
5. **Build the invisible UI**: every state in [States](#states-the-invisible-ui). Done when every interactive element and data region has its full set.
6. **Add motion** only where it confirms an action, directs the eye or carries the brand. Read [MOTION.md](MOTION.md) first.
7. **Verify the rendered page, not the code.** Screenshot it with Playwright at desktop and mobile widths, in light and dark if both exist, and fail on any page error. Static shots miss the invisible UI, so script each state and shoot it too: hover, open modal, form errors, a toast, selection, loading, empty, error. Stress-test with variant content: longest and shortest strings, labels 3× longer, empty data, 10k rows, the brightest and the busiest image. Run axe-core (`@axe-core/playwright`) where available and Tab through the whole page. Done when every rule in this file and the branch files you read holds in the screenshots, axe reports no violations, every control is reachable by keyboard with visible focus, the page is never wider than the viewport, and it still works at 320px width and 200% zoom.

## Hierarchy

- Rank is expressed with three levers: **size, position, colour**. Rank 1 is biggest, highest and most distinct. Rows of equal size and weight read like a spreadsheet.
- **Proximity is hierarchy.** Start with a uniform gap (e.g. 32px between every hero item), then tighten the pairs that belong together. Spacing expresses relationship, so a big gap between related sections is a bug.
- **Signifiers** replace instructions: a shared container means related, a filled segment means selected, greyed text means inactive. If a control needs explanatory copy, a signifier is missing.
- Shape can replace labels: origin and destination icons on one vertical line say "from → to" without words. A currency symbol already says "price". Label every sibling in a group or none (keep an `aria-label`).
- An attribute the user chooses lives in the control, not the title ("Strawberries", with "1 kg" in the quantity selector).
- Keep what users need in view. Working memory holds about 4 chunks, so information needed at step N is shown at step N, not remembered from step N−1.

## Spacing and layout

- **4pt scale**: every spacing value is a multiple of 4, so each one halves cleanly.
- One left content edge per screen (e.g. 24px). Every text, icon, price and button starts on it. Users feel misalignment they never consciously see.
- Column grids (12 desktop / 8 tablet / 4 mobile) pay off for repeating content and breakpoints. Bespoke marketing sections may ignore columns but keep the 4pt scale.
- Buttons: horizontal padding = 2× vertical (`12px 24px`).
- **Text boxes grow.** Anything holding text gets `min-height` and intrinsic width: never a fixed height, fixed width or `overflow: hidden`. Translated labels run up to 3× longer, and users override text spacing and zoom.
- `@container` queries for components that sit in more than one slot; `@media` for the page shell. Full-height sections use `100svh` or `100dvh`.
- Images carry `width` and `height` attributes, and async regions reserve `min-height`, so nothing shifts on load (CLS ≤ 0.1). Animate only `transform` and `opacity`.

## Typography

- One family by default. Hierarchy comes from size, weight, colour and line-height. Add a second family only for brand character (see MARKETING.md).
- Sizes in `rem`. Fluid `clamp()` type keeps its maximum ≥ 2× its minimum, or 200% zoom barely enlarges it.
- Large headings: `letter-spacing: -0.02em` to `-0.03em`, `line-height: 1.1`–`1.2`. Body keeps normal tracking and ~1.5 leading.
- Body prose: `max-inline-size: 65ch` (50–75 characters per line).
- Small uppercase labels: `letter-spacing: 0.04em`–`0.08em`.
- Body text is a softer grey than headings. Headlines attract; paragraphs support.
- Primary CTA in sentence case. Its emphasis comes from colour and position.
- Size range: marketing uses at most 6 sizes across a wide range; product UI tops out at 24px with small steps. Inputs are at least 16px on touch screens (iOS zooms into smaller ones).
- Numbers in columns: right-aligned, `font-variant-numeric: tabular-nums`. Numbers, dates, currency and plurals go through `Intl.*`; strings are whole messages with placeholders.

## Icons, dividers, shadows

- Icon size = line-height of the adjacent text (24px line → 24px icon), then tighten the icon–text gap.
- One icon set: all outline or all filled, one stroke weight. Icons inherit the text colour (`fill="currentColor"`); colour marks status only (active tab, destructive).
- Dividers are low-contrast hairlines (around 85% lightness in light mode). They separate; they are not meant to be seen.
- Shadows: low opacity, large blur, strength rising with elevation. Cards get a whisper; popovers, menus and modals get more. If the shadow is the first thing you notice, halve it. Inset + outer shadow together make a tactile button.
- Shadows and gradients vanish in Windows forced-colours mode, so anything that must stay visible (focus, card edge, selection) also has a border or outline, transparent if need be.
- Controls over imagery get their own semi-opaque container and a thin outline so they read on any image.

## Accessibility baseline

Six markup errors make up 96% of detected accessibility failures on the web (WebAIM Million 2026). Emit all of these by default.

- `<html lang>`. Every image has `alt` (`alt=""` for decoration). Every icon-only button and link has an accessible name. Every input has a visible `<label>`.
- Structure: one `<h1>`, headings in order without skipped levels, `<main>`, `<nav>`, and a skip link.
- **Native first**: `<button>`, `<a href>`, `<dialog>`, `<details>`, `<input>`, `<select>`. Pages using ARIA average more errors than pages without; every custom role commits you to its keyboard contract (WIDGETS.md). Site navigation is `<nav>` with links, never `role="menu"`.
- **Focus**: `:focus-visible { outline: 2px solid <focus token>; outline-offset: 2px }`, at 3:1 against its surroundings. `html { scroll-padding-block: <sticky header height> <sticky footer height> }` keeps focused elements out from under sticky bars.
- **Targets** ≥ 24×24 CSS px everywhere; 44px for touch and standalone controls. Grow the hit area with a `::before` (`inset: -10px`) rather than enlarging the glyph.
- **Contrast is computed, not asserted**: 4.5:1 for text, 3:1 for large text, borders of controls, icons, state indicators and focus. Colour is always paired with an icon, text or shape.
- Every drag has a click alternative (Move up/down buttons, a "Move to…" menu). Paste always works, including in password and code fields.

## States: the invisible UI

A finished product is mostly states nobody sees in a static mockup. Ship all of them.

- **Buttons**: default, hover, active (`scale(0.97)` or one ramp step further), `:focus-visible`, disabled, and loading (spinner) when async.
- **Inputs**: focus; error (red border **and** message); warning for non-blocking issues. Timing and wording live in FORMS.md.
- **Data regions**: loading, then exactly one of: content; empty, named by its cause (first use with a create action, no results with the query editable and filters clearable, no permission with who to ask, setup required with the next step); or error with retry and whether work was saved. Render "empty" only after loading completes.
- **Waits**, by expected duration:

  | Wait | Show |
  |---|---|
  | < 0.1 s | Instant state change, same frame |
  | 0.1–1 s | Nothing, or a subtle inline "Saving…" |
  | 1–10 s | Skeleton matching the final geometry (page or region) or spinner (one module), plus status text |
  | > 10 s | Determinate progress, stage text ("3 of 12 files"), and Cancel |

  Delay any indicator ~300ms and keep it up ≥ 300ms once shown, so fast loads never flash (convention, not research).
- **Feedback confirms the result, not the click**: copy → a "Copied" chip slides up; modal submit → a toast, since the modal hid the change.
- **Toasts** are `role="status"` and carry success or info only: they auto-dismiss after ≥ 5 s, pause on hover and focus, and have a close button. Errors go inline or in a persistent banner, where they cannot fade unread. A toast with an action (Undo) stays until dismissed or the next action.
- **Destructive actions**, three tiers: reversible → act at once, offer Undo; irreversible → a dialog naming the object and consequence ("Delete 3 events?"), buttons named for outcomes ("Delete events" / "Keep events"), initial focus on the safe one; rare and catastrophic (delete project, org, data) → also type the name to confirm. Optimistic updates are for reversible, low-stakes actions only, never payments or messages to other people.
- **Tooltips** on every icon-only control and ambiguous label: shown after 500ms of hover or on focus, Esc dismisses, the pointer can move onto them, no timer. Essential information lives somewhere permanent too.
- **Hover-revealed actions** also appear on `:focus-within`, and are gated to `@media (hover: hover) and (pointer: fine)`: touch gets them always visible or in an overflow menu. Give touch rows a slightly darker press state.
- Help, contact and chat sit in the same place on every page.
