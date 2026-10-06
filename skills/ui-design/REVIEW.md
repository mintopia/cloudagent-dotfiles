# Review

For critiquing or auditing an existing interface. Walk every rule in SKILL.md and the branch files that apply, then this rubric.

## Heuristic checks (Nielsen's 10, made checkable)

| Heuristic | Check |
|---|---|
| Visibility of system status | Feedback within 100ms of every input; the wait table in SKILL.md followed; active nav item marked (`aria-current`); "Step X of N" in flows |
| Match with the real world | Labels in the user's words, not internal or database names; units and formats per locale |
| User control and freedom | Esc and a visible close on every overlay; Undo for reversible actions; Back keeps entered data and filter state |
| Consistency and standards | Same action, same word and place everywhere; platform conventions for controls and shortcuts |
| Error prevention | Constraints and good defaults over warnings; destructive actions never the default or nearest target |
| Recognition over recall | Labels always visible; information needed at a step shown at that step; recent items and search history offered |
| Flexibility and efficiency | Keyboard shortcuts and bulk actions for frequent tasks, layered on visible paths |
| Aesthetic and minimalist design | Every element earns its rank; nothing competes with rank 1 |
| Recognise and recover from errors | Message next to the field, linked by `aria-describedby`, says how to fix it; input preserved |
| Help and documentation | Help in a consistent place; tooltips and empty states teach in context |

## Severity

Rate each finding 0–4 by frequency, impact and persistence: 0 not a problem, 1 cosmetic, 2 minor, 3 major (fix soon), 4 catastrophe (fix before release). Single-reviewer ratings are unreliable; say so, or run several independent passes and average.

Report format: `[heuristic or rule] [severity] location: problem, evidence (screenshot or DOM), fix`.

## Deceptive patterns

Banned in the EU for online platforms (DSA Art. 25) and pursued by the FTC. One test catches most of them, **symmetry**: whenever the business prefers one answer, the other answer takes the same number of clicks, the same visual weight, the same layer and neutral wording.

| Pattern | Build instead |
|---|---|
| Confirmshaming ("No thanks, I hate saving money") | Neutral decline: "No thanks" |
| Preselected add-ons or consents | Optional items start unchecked |
| Hidden costs | Full price including mandatory fees from first display |
| Roach motel (easy in, hard out) | Cancel in as few steps as signup, from the same place |
| False urgency or scarcity | Timers and stock counts only from real data |
| Nagging | One ask; respect the answer for the session or longer |
| Trick questions (double negatives) | One plainly worded positive question per choice |
| Unequal consent buttons | "Reject all" beside "Accept all" at the same size and style |

## Evidence grades

Cite UX laws in their corrected form:

| Principle | Status | Use it as |
|---|---|---|
| Fitts's law | Solid | Bigger, closer targets are faster; keep destructive actions away from the nearest, largest spot |
| Hick–Hyman | Solid, narrow (equally likely, familiar choices) | Mark a recommended default for frequent decisions; it doesn't justify hiding items in long ordered lists |
| Miller's 7±2 | Misapplied | Visible menus need no 7-item cap. For what users must hold in mind, design for ~4 chunks (Cowan) and keep information visible |
| Zeigarnik effect | Failed replication | Use the supported tendency to resume: show where users left off and offer one-click resume |
| Choice overload | Average effect near zero, context-dependent | For comparable plans, 3–4 tiers with one recommended |
| Aesthetic-usability | Contested; usability drives perceived beauty more than the reverse | Polish never lowers the severity of a functional defect |
| Doherty 400ms | 1982 mainframe productivity data | Use the 0.1 / 1 / 10 s limits and INP ≤ 200ms |
| Thumb zone | Contradicted by field data | See RESPONSIVE.md |
| Skeletons feel faster | Mixed evidence | Value is structure preview and no layout shift |
| Peak-end rule | Supported | Spend craft on errors, confirmations and endings |
| Goal-gradient | Reasonably supported | "Step 2 of 4"; credit only real completed work |

Where sources disagree (GOV.UK submit-only validation and "(optional)"-only marking vs Baymard and NN/g), state which context applies rather than picking one silently.
