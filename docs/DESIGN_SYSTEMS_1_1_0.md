# Reach 1.1.0 — Expressive design systems

This upgrade replaces the former palette-based theme switches with ten structural looks. Each controls the shape, color, type scale and density of Material components **and** the Discover-page header, feed-card hierarchy, filter layout and navigation. Existing IDs remain stable so saved preferences are migrated automatically.

| Look | Navigation | Discover heading | Feed surface | Distinction |
|---|---|---|---|---|
| Aurora Flow (default) | floating pill dock | gradient spotlight | airy floating cards | violet/cyan, soft motion |
| Editorial Ink | underline tabs | Swiss type/editorial | typographic separators | cream/black, serif, deliberate whitespace |
| Obsidian Pro | floating dark dock | premium gradient | left-accent rails | dark gold/graphite |
| Coastal Glass | Material 3 bar | quiet brand | soft floating cards | large radii, blue/white breathing space |
| Terra Social | independent tile tabs | editorial type | terracotta accent rails | warm community |
| Neon Circuit | rail on tablet, tech tiles on phone | compact command | dense rows | dark signal green, condensed |
| Alpine Focus | minimalist underline | editorial type | concise rows | botanical, quiet serif |
| Sakura Bento | dock | radiant spotlight | bento panels | pink/purple expressive |
| Blueprint Studio | rail on tablet, tech tiles on phone | compact grid | precise editorial rows | technical blue, mono |
| Solstice Pop | tile tabs | lively spotlight | bento panels | bright citrus, playful |

## Functional guarantees

- All five destinations remain available in every look, including phone portrait. A side rail is enabled only on wider displays with enough height, otherwise it safely falls back to compact bottom navigation.
- Search, category/type filters, nearby radius, people search, Reach Assist, Refresh, posts, requests, private chat, privacy, calling and reporting use the same underlying functions regardless of the look.
- Short displays use a single accessible filter sheet instead of taking most of the screen with two fields. Landscape/tablet layouts may render multiple bento cards side by side.
- Design studio has *illustrative previews* only; no fabricated community accounts or posts.
- Every style retains Material 3 semantics, screen-reader labels, system font scaling, light and dark themes. No third-party fonts, paid icon packs, API keys or analytics are required.
- Look choice is persisted as `reach_visual_preset`; legacy IDs `aurora`, `editorial`, `obsidian`, `coastal`, `terra`, `circuit`, `alpine`, `sakura`, `blueprint`, `solstice` are preserved.
- Theme transitions are local and do not contact the server.

## Release quality gates

1. Flutter analyze and widget tests including ten unique composition assertions, gallery selection, multi-look navigation and rail breakpoints.
2. Signed Universal and ARM64 APK and signed Play internal-test AAB from version `1.1.0+10`.
3. QA: rotate two devices; test smallest supported phones, large fonts, 5-tab reachability, filter sheet, login, discovery, messages, privacy toggles and call consent in at least three contrasting looks.
4. Google Play production publication remains subject to separate store compliance and real-device user journeys.

## UI restrictions and intentional fallbacks

- Rails never consume half of a narrow phone. On smaller screens, Rail looks use compact tiled bottom navigation.
- Bento only uses two columns when at least 610 logical pixels of feed width are available; otherwise it presents one readable column.
- Platform system sans, serif, mono and condensed families are used, so exact glyph metrics may differ by Android build.
