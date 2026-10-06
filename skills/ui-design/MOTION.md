# Motion

Product UI motion is tame and serves the user; chart hover is the exception. Marketing motion is identity: pick 1–2 **signature motions** and repeat them across the site, since one-off effects never add up to a brand. Under `prefers-reduced-motion: reduce`, swap travel, zoom and parallax for an opacity change or an instant state change: keep the feedback, drop the movement. Anything that moves automatically for more than 5 s gets pause or stop, whatever the motion setting, and nothing flashes more than 3 times a second.

## Spring

Springs beat stock easing on anything that pops in. Reference spring: stiffness 636, damping 24, mass 1 (~18% overshoot, settles in ~350ms). Pass these straight to Framer Motion or React Spring; in CSS approximate with `cubic-bezier(0.34, 1.56, 0.64, 1)` over 400–500ms, or a `linear()` curve sampled from the spring.

## Page-level

- **Bookends**: scrolling past the hero, its elements slide off and its text blurs while the next section slides up _over_ it, so the hero becomes a background layer. Mirror this on the closing CTA.
- **Character entrances** for decorative objects, never a flat fade: a star rotates and scales in; a balloon flies in from off-screen, then bobs on a loop; a calendar translates and rotates in.
- **Parallax** for objects in wide side margins: depth without heavy layered backgrounds.
- **Headline animation**: lines fade in and slide down one by one; a key word can turn into its meaning ("deadlines" becomes a filling progress bar, then the word returns).
- **Image rotation**: several equally important images auto-rotate on a timer; each zooms slightly on hover (`scale(1.03)` inside `overflow: hidden`).
- A simple site stays alive with small hover reactions on nearly everything, or one reveal effect (message bubbles un-blurring).

## Micro-interaction catalogue

1. **Rolling button label.** `overflow: hidden` wrapper with two stacked copies of the label; on hover both translate up 100%. On `:active`, `scale(0.97)`. Clear hover and press states with no new colours.
2. **Keycap shortcut hint.** Render the shortcut as keycaps; each one presses down as its key goes down (`keydown`, `metaKey`/`shiftKey`). A success message appears when the full combo is held.
3. **Rich toast.** Slides up; can hold an inline spinner that resolves into success, optionally with a particle burst.
4. **Name tag on avatar hover.** A black pill label with white text, slightly rotated, rises from a little below at opacity 0 to rest at opacity 1, with the reference spring.
5. **Shimmer border.** A ring (a `::before` with `mask-composite: exclude`) filled with a conic gradient whose angle animates continuously (`@property --angle`). Include a pause toggle.
6. **Delayed tooltip.** Appears after 500ms of hover (up to 1000ms in dense icon bars, so sweeping the pointer doesn't fire a stream of them) with a slight overshoot; hides on leave or Esc.
7. **Text hover pop-out.** Hovering a phrase in body copy pops a related image beside it: shows what you mean without spending layout space.
8. **Drawing stepper.** In a multi-step form, the line between step circles draws in (`stroke-dashoffset` or `scaleX` from `transform-origin: left`); everything else fades.
9. **Card-stack dismiss.** The top card rotates away and fades; the cards behind scale up and move forward **while** it is dragged, not after.
10. **Search expands from icon.** A magnifier morphs through an intermediate state into the full input, the glass sinking into the circle.
11. **Upgrade preview on hover.** Hovering a usage limit slides the higher plan's value in, replacing the current one (no strikethrough).
