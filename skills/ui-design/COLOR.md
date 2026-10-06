# Colour

Lightness values below are HSL lightness of a neutral (85% ≈ `hsl(0 0% 85%)`). Tint any neutral toward the brand hue for flavour (a purple-tinted grey).

## The four layers (product UI)

Product UI is far more neutral than 60-30-10: Vercel is roughly 90% black, 8% white, 2% red. Build four layers:

1. **Neutral foundation**: carries the screen.
2. **One functional accent**: primary actions, focus, links, active state.
3. **Semantic colours**: green success, yellow warning, red danger, blue info. Destructive actions are red whatever the brand colour. Notification badges may use the brand colour.
4. **Optional theming** (below).

Every coloured element should answer "what does this colour mean?". Sibling cards share one colour; giving each its own hue is the classic mistake. Opacity variants of one colour look bland; for data series use the chart method below.

## Neutrals (light mode)

Define them as tokens up front. A product needs about 4 background layers, 1–2 borders, 3 text colours, then hover states; a landing page needs 3–5 neutrals.

- **Page**: pure white is fine (Notion 100%, Linear 99%, Vercel 98%). If cards are white, the page goes off-white.
- **Adjacent layers**: about 2% lightness apart. The sidebar or app frame is the darker anchor (~2% darker, optionally ~2% toward the brand hue).
- Light mode can go either way: darker page with lighter cards, or the reverse. Darker cards reuse the sidebar colour.
- **Borders**: about 85%. For cards on a near-identical background, an 85% border beats a black hairline or a shadow. Sometimes a border alone beats adding another filled surface.
- **Text**: key headings ~11%, body 15–20%, subtext 30–40%. Most text is grey, not black.
- **Buttons**: importance tracks darkness, from ghost through grey (90–95%) to black with white text.

## Accent ramp

Generate a full 50–950 ramp (e.g. uicolors.app), never a single hex.

| | Light mode | Dark mode |
|---|---|---|
| Primary | 500–600 | 300–400 |
| Hover | 700 | 400–500 |
| Links | 400–500 | 300 |

The table is a starting point; contrast decides. The primary fill is the lightest step that passes 4.5:1 against its label (white in light mode, the 950 step in dark mode). Teal, green, orange and yellow usually need 700 in light mode, then hover and pressed shift down one step each. Pressed goes one step past hover. Disabled is a desaturated version (light grey fill, white text reads as disabled in both modes). Tints of the primary (50–100) make subtle backgrounds; dark shades (800–900) make brand-tinted text.

## Brand colour fixes

- A saturated brand colour on a low-rank element (large cards): drop to a pale tint and switch the text to dark. Attention matches rank, and saturated fills often fail contrast.
- A brand colour that fails contrast with white text: darken it until it passes, or pair it with a passing complementary colour (Mailchimp yellow + turquoise).
- Too few brand colours: rotate the hue a little for analogous companions, or take the complement.
- On marketing pages, sample the base palette from the brand imagery, then add accents.

## Dark mode

Build dark mode for its own goals; inverting light mode loses every surface distinction.

- **Elevation = lighter.** Each raised surface is lighter than what's below, or carries only a border. Shadows barely show. Controls count as surfaces: a secondary button inside a toast or modal is lighter than that toast or modal.
- **Double the steps**: layers 4–6% lightness apart (vs ~2% in light mode).
- Borders sit one subtle step lighter than their surface. An inverted light-mode border glares.
- Text: light greys, dimmed more aggressively than in light mode. Pure white only for the most important text and figures. Brand-tinted dark text becomes neutral light grey.
- Chips: drop background saturation and brightness, and use the bright tone for the chip **text**.
- Slightly desaturate saturated brand elements (logo).
- The background may be a deep purple, red or green, not only grey or navy.

## Charts

A single-brand ramp makes series look alike; HSL makes green look neon beside blue. Use OKLCH: fix L and C (check at oklch.com), then step the hue 25–30° per series.

## Theming

To theme a neutral palette with a hue: convert each neutral to OKLCH, lower L by 0.03, raise C by 0.02, set H to the theme hue. Works for any hue and especially well in dark mode.
