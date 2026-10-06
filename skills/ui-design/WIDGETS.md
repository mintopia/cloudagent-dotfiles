# Widget contracts

Keyboard and screen-reader behaviour for custom widgets, from the WAI-ARIA Authoring Practices (APG). Automated scans cannot see these failures, so build them in deliberately and verify by keyboard.

## Ground rules

- A native element beats ARIA whenever one exists. ARIA adds no behaviour: every role you add is a promise to write its keyboard handling yourself.
- `aria-hidden="true"` and `role="presentation"` never sit on a focusable element or its ancestors.
- A composite widget (tabs, menu, listbox, grid, toolbar, radio group) is **one Tab stop**; arrow keys move inside it. Use roving `tabindex`: the active item `0`, the rest `-1`.
- Any overlay you open stores `document.activeElement` first and restores focus to it on close.

## Dialog

- Native `<dialog>` opened with `showModal()`: it moves focus inside, makes the page inert, sits in the top layer and closes on Esc.
- Name it with `aria-labelledby` pointing at its heading.
- Initial focus goes to the first field, or to the least destructive button in a destructive confirm.
- A visible close button as well as Esc; clicking the backdrop may close a non-destructive dialog.

## Disclosure, accordion

`<details>`/`<summary>` where possible. Otherwise a `<button aria-expanded aria-controls>` toggling a region.

## Menu button

For action menus only (site navigation uses `<nav>` with links). `<button aria-haspopup="menu" aria-expanded>` opens a `role="menu"` with `role="menuitem"` children. Enter, Space or ↓ opens and focuses the first item; ↑ the last. Arrows move, Home/End jump, typing a letter jumps to the matching item, Esc closes and returns focus to the button, Tab closes and moves on.

## Tabs

`role="tablist"` > `role="tab"` (`aria-selected`, `aria-controls`) and `role="tabpanel"` (`aria-labelledby`). ←/→ move between tabs and wrap; Home/End jump. Activate on focus only when panels render instantly; otherwise move focus with arrows and activate with Enter or Space. Tab from the tablist goes into the panel.

## Combobox, autocomplete

DOM focus stays in the `<input role="combobox" aria-expanded aria-controls aria-autocomplete="list">`. ↓/↑ move through the `role="listbox"` options via `aria-activedescendant`; Enter selects; Esc closes, a second Esc clears. Style the typed portion and the suggested portion differently.

## Sortable table, data grid

- Sortable headers: the header text is a `<button>`, and `aria-sort` sits only on the currently sorted column.
- Interactive grid (`role="grid"`): arrows move between cells, Home/End to row ends, Ctrl+Home/End to table ends, Enter or F2 edits a cell, Esc cancels the edit.
- A plain table that scrolls sideways sits in a focusable wrapper: `<div tabindex="0" role="region" aria-label="Events table">`.

## Tooltip

`role="tooltip"` linked from the trigger with `aria-describedby`; timing and dismissal as in SKILL.md. Tooltips carry descriptions only, never interactive content.

## Live regions, toasts

- Render one empty live region at the app root and inject text into it; regions added at the same moment as their text are often not announced.
- `role="status"` (polite) for confirmations and progress; `role="alert"` (assertive) only for urgent problems: lost connection, session expiring. Interactive content never lives inside an alert.
- Time limits are adjustable to 10× or extendable with ≥ 20 s warning.

## Drag and drop

Every drag has a single-pointer alternative: Move up/down buttons on sortable rows, a "Move to…" menu on board cards, a numeric input or track click beside a slider. Keyboard support alone does not satisfy WCAG 2.5.7.
