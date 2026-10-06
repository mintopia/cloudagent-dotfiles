# Marketing pages

Landing pages, homepages, feature and pricing pages, 404s. Here identity does the work: a page that is clean, minimal and well animated still reads as generated if it has no point of view.

## Order of work

1. **Identity board.** One moody hero image from the audience's world (cropped, darkened, grain, brand name). More images in the same mood. A base palette sampled from those images plus a few accents ([COLOR.md](COLOR.md)). Textures. Fonts. Icons in the accent colours.
2. **Frankenstein wireframe.** Assemble the page flow from sections of real shipped sites (galleries such as Mobbin), adapt each, keep only the wireframe.
3. **Apply the identity section by section**: background → texture → type → images and icons.
4. **Motion last**, as a repeated brand motif ([MOTION.md](MOTION.md)).

Identity and wireframe stay separable: the same wireframe with another identity should feel like another brand.

## Generated-page tells

Each is a target, with the tell it replaces:

- **Real imagery everywhere**, large enough to dominate its section, showing the audience's world (laptops for freelancers, kitchens for restaurants). No images at all is the clearest tell of a generated page.
- **The audience shapes the visuals**: imagery, textures, icon motifs and font personality all say who it's for. The copy naming the audience is not enough.
- **One actionable promise in the hero**, saying exactly what the product does.
- **A palette sampled from the imagery**, instead of sterile bright light mode or flat default dark mode.
- **Fonts chosen for the domain**: one sans, plus a serif when the brand needs character (a restaurant serif evokes a printed menu; a split heading, one line sans and one line serif, works in a hero). Monospace fits developer brands only.
- **Fewer words, bigger images.** Cut feature text hard.
- **Plain human copy** ("we sweat the details") over corporate phrasing.
- **Shared primitives**: build sections from one component set so the page stays consistent.

## Hero

- Gap between subtext and buttons ≥ 2× the gap between heading and subtext. A large heading's line box already adds visual space below it.
- Heading and subtext form a tight group; announcement bar and heading form another.
- Decorative objects scattered around a centred message: larger ones behind, smaller ones on top, a clear safety margin around the text. Density and size fall off with distance from the centre; tilts point inward. Leave an empty spot empty rather than adding one more object.
- A vignette (darkened edges) pulls the eye to the centred text.
- Pick the playfulness level on purpose: blobs and bright colour (most playful) → doodles or neo-brutalism → realistic imagery (professional). Sparkles and a few scribbles add life at any level.

## Sections

- Each section gets its own background from the brand kit (brand colour, image, or cream) with its own grain strength, so the page has rhythm.
- **Grain**: a noise overlay adds texture and improves text contrast on images. Stronger on image sections; none where a clean software feel is wanted.
- Section textures tied to the brand (a graph-paper grid on cream for features).
- Text over images: a linear gradient that shows the image, then fades into a solid area behind the text. Fancier: a progressive blur (stacked `backdrop-filter` layers under gradient masks).
- Example flow: hero → logo marquee → how it works on big background images → features as full-screen colour tabs with big images → testimonials (open, no dividers) → closing CTA, heavy type, image background, left-aligned → footer.
- Social proof is a logo strip **plus** testimonials.
- 60-30-10 colour split (dominant, secondary, accent) works here; the accent may be white.
- The 404 page is the place for quirk: a mini-game, character or quiz in the site's tone.
