# Product UI

Dashboards, app screens, admin, settings, mobile app screens. Density is high, motion is tame, colour comes from the data. The main area shows the one thing this user's domain cares about most (project status, portfolio value); if the screen looks like it needs a manual, cut it.

## Data drives the form

Pick each element's form from the data's shape (step 2 of SKILL.md):

| Shape | Form |
|---|---|
| Small fixed set (status, department) | chip or badge |
| Number | right-aligned, tabular figures |
| Long text | truncate with ellipsis; full text in tooltip or detail |
| Time-ordered events (activity, history) | timeline in a side panel or second column, with a small trend chart above |
| Actor | avatar beside the name |
| Inactive record | whole row dimmed |
| Urgent or destructive event | red icon or chip, the only colour in the log |

**Completeness**: a table becomes a tool once it has search, filter and sort. Every displayed object has its actions (create, edit, detail, bulk). Checkbox selection reveals a contextual bulk-action bar.

## Spectrum of explicitness

Rank each action, then place it on the spectrum, most to least explicit:

1. Always-visible labelled button: page-level primary ("Create link").
2. Always-visible icon (with tooltip).
3. Icon revealed on row or cell hover, with tooltip: per-row secondary actions (remove user, copy cell).
4. Gesture: swipe to reveal on mobile, with the primary action (check off) still visible.

Dense tables need the low end: a copy chip on cell hover, a corner-triangle marker for comments.

## Where a feature lives

Most new features need no page of their own. Pick the lightest container that fits:

- **Popover**: simple, non-blocking context (display settings, Share). Click away with no consequence. Its primary action sits at the top (the invite input in Share).
- **Modal**: a blocking task tied to what's on screen (Create over the list). Confirm with a toast after submit.
- **Drawer or side panel**: secondary detail beside the main content (activity timeline).
- **New page**: permanent or large context (one item's detail). Needs a back button or breadcrumb.
- **Tabs**: different views of the same data without adding sidebar items.

The four building blocks are lists/tables, cards, inputs/forms and tabs; most screens compose them (a settings modal = list + inputs + cards).

## Navigation

- Sidebar holds the persistent, global items: nav, workspace or profile switcher, search.
- Top slot: the workspace or profile switcher (avatar, name, up/down chevron), which earns it more than a logo.
- Each item is an icon plus a short label, so the bar can collapse to an icon rail and labels leave room for a count or "New" chip.
- Group links into sections; nest long groups in collapsibles; pin Settings and Help to the bottom.
- The active item always shows (a small bar or filled background). Nav items are ghost buttons: no fill until hover.
- The top strip of the main area holds page-level actions: filter or sort plus the primary button.
- Primary navigation stays visible at desktop widths: hiding it behind a menu button cut discoverability almost in half in NN/g testing. A ⌘K command palette accelerates visible navigation; it never replaces it.
- Breadcrumbs on hierarchies deeper than two levels: they show the hierarchy, not history, and the current page is last, as plain text with `aria-current="page"`.
- Hover menus open after the pointer rests 0.5 s and close 0.5 s after it leaves both trigger and panel.
- **State lives in the URL**: tab, filter, sort, page and search query, so Back, refresh and shared links restore the view (`replaceState` while typing, `pushState` for discrete choices).

## Search and filters

- A visible search box, not a search icon that opens one (a visible box raised search use 91% in NN/g's test).
- Zero results: say so prominently, keep the query editable, suggest alternatives in the main content, and offer to clear each active filter.
- Allow several values per filter (OR within a facet), and show a count beside each value ("Sold out (2)").
- Applied filters appear as chips naming type and value, each removable in one tap, plus "Clear all".
- Desktop applies filters live when results return in under 1 s. Mobile batches changes in a drawer behind a sticky "Show 24 results" button.

## Lists, tables, cards, charts

- Separate list items with space, dividers or a background fill. A stacked list in one container is calmer than individually bordered items.
- Rows stay minimal (favicon, title, URL, date, count); a one-line description can use spare middle width.
- Tables serve four tasks: locate, compare, view or edit, act. Freeze the header row, and the first column on wide tables. Row hover or zebra striping keeps the reader's place.
- Row density tokens: 24 / 32 / 40 / 48 / 64px, default 40; header and bulk-action bar match the row height.
- Hiding and reordering columns works through a menu, never drag alone; show "4 columns hidden" when any are.
- Long tables paginate with a total count, or use "Load more", with the page in the URL. Infinite scroll suits browse-only feeds, never finding tasks.
- **Tables on narrow screens** keep the rank-1 columns in view: a scroll wrapper with a sticky first column, or row cards (RESPONSIVE.md).
- Cards separate from the page by a border **or** a fill, not both.
- Charts: a line chart for time series, a bar chart for per-item breakdowns. Always gridlines and axis values. Card anatomy: headline figure, date-range selector, chart, an optional metric switch, item identifiers (favicons) beside bars.
- Chart hover is where product UI may play: a value bubble with % change on line hover; dim the other bars on bar hover.

## Onboarding

Progressive disclosure over time. Open on one tooltip pointing at the single most important action; after it's done, reveal the next, or a small corner checklist. Sequence features rather than explaining them all in one modal.

## Mobile detail screens (commerce)

- The first viewport answers: what is it, can I trust it (rating beside the title), what does it cost (price near the title).
- Content sits on a sheet with rounded top corners sliding over a full-bleed image.
- When the image scrolls away, the title moves into a sticky top bar.
- A sticky bottom bar holds the quantity selector beside Add to cart; the CTA shows the total ("Add to cart · $12.40").
- Preset chips for common values (500 g / 1 kg / 2 kg) beside a stepper.
- Badges use the fewest words ("20% off").
- Catalog images work as a system: one focal point, consistent background and lighting, showing the unit actually sold.
