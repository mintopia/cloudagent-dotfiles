# Forms and copy

Forms carry the strongest quantified evidence in UX. Inline validation timed on blur gave 22% higher success, 22% fewer errors and 42% faster completion than submit-only (Wroblewski, 2009, n=22, corroborated by Baymard).

## Before building: cut fields

The average checkout has 11.3 fields where ~8 suffice, and 17% of users have abandoned one for complexity. Field count matters more than step count. Remove every field that can be inferred, defaulted, deferred or merged. Ask once: carry earlier answers forward ("Billing same as shipping"), and keep wizard state across steps.

Long or unfamiliar flows: one question per page with a final "Check your answers" page (GOV.UK). Show "Step 2 of 4".

## Layout

- **One column.** Only short related fields share a row (city / postcode, expiry / CVC).
- **Labels above fields**, always visible. Placeholder text is never a label: it vanishes on input and its default colour fails contrast. Floating labels are an untested compromise; prefer top labels.
- **Width signals expected length**: `max-width` in `ch` matched to the answer (postcode 10ch, year 4ch, phone 20ch).
- Mark required fields with an asterisk **and** optional ones with "(optional)". On forms where nearly everything is required (GOV.UK style), "(optional)" alone is enough.
- 2–3 options → radio buttons, not a select. Never place Reset beside Submit.

## Validation timing

- Never validate on focus or while the user is still typing a fresh value.
- Validate on blur, only if the value changed.
- Once a field shows an error, re-validate on every `input` event so the error clears the moment the value becomes valid.
- Success ticks only where users are unsure (username availability, password rules); on trivial fields 50–70% never notice them.
- One question per page (GOV.UK pattern): validate on submit only.

## On submit

- Keep every value the user typed (except passwords).
- Prefix `document.title` with "Error: ".
- Show a summary at the top headed "There is a problem", listing each error as a link to its field, and move focus to it.
- Repeat the identical message next to each field: `aria-invalid="true"` and `aria-describedby` pointing at the message.
- Keep the submit button enabled and explain what's missing on submit; disabled buttons are low-contrast and silent. Block double submission with an in-flight flag and a loading state.
- Accept forgiving input and normalise it: postcodes with or without spaces, phone numbers with spaces or dashes, names with diacritics.

## Field markup

Carry these verbatim (WCAG 1.3.5 requires `autocomplete` on personal data):

| Field | Markup |
|---|---|
| Email | `type="email" autocomplete="email" spellcheck="false" autocapitalize="off"` |
| Phone | `type="tel" autocomplete="tel"` |
| Numeric code, ID, card | `type="text" inputmode="numeric"` (`type="number"` is for quantities); card adds `autocomplete="cc-number"` |
| One-time code | one field, `inputmode="numeric" autocomplete="one-time-code"`; per-digit boxes break paste |
| Sign-in password | `type="password" autocomplete="current-password"` |
| New password | `autocomplete="new-password"`, a Show toggle instead of a confirm field, minimum 8 characters |
| Known date (birth) | three fields Day / Month / Year at 2 / 2 / 4ch, `inputmode="numeric"`, no auto-advance |
| Name | one "Full name" field, `autocomplete="name"`, any characters accepted |
| Address | `autocomplete="street-address"`, `postal-code`, `country-name` |

Bot protection: a honeypot field or server heuristics. Image and text CAPTCHAs exclude screen-reader users.

## Error messages

Say what happened and how to fix it, in the user's terms. Templates (GOV.UK):

| Case | Message |
|---|---|
| Empty text field | "Enter your email address" |
| Empty choice | "Select a ticket type" |
| Too long | "Event name must be 80 characters or less" |
| Out of range | "Date must be after 1 January 2027" |
| Impossible value | "Date must be a real date" |
| Wrong format | "Enter an email address in the correct format, like name@example.com" |

Write plainly and without blame: drop "please", "sorry", "oops", "invalid", "illegal" and error codes. Problems the user cannot fix in the field (ineligible, no permission, sold out) get their own explanation and next step, not a field error. If many users hit the same error, redesign the interaction rather than the message.

## Microcopy

- Buttons are a verb plus an object naming the outcome, in sentence case: "Create event", "Send invoice", "Delete 3 files". "Submit", "OK" and "Yes" say nothing.
- Confirmation copy names exactly what will happen and to what.
- Numbers as numerals, commas above 999, the % sign, a leading zero (0.5), ranges as "5 to 10" in prose.
- Dates written out unambiguously ("5 October 2026"), formatted per locale through `Intl.DateTimeFormat`.
- These are design-system guidelines (GOV.UK, Apple), not A/B-tested results; adapt the tone to the brand, keep the structure.
