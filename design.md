# Barricade Advisor — Design Spec ("Maple · Sage felt")

The look is a **warm wooden games table**: a maple frame around a sage-green felt
board, cream paper controls, glossy resin pieces, and a small amount of quiet
motion. Everything below lives in `Theme.swift`; **pull colors and gradients from
there, never hard-code hex in views** (the few one-off `Color(hex:)` calls in
views are intentional local washes).

Source of truth for this vibe: the Claude design canvas (`Barricade Game.dc.html`,
option **1b**). This file is the durable summary — match it when extending the UI.

## Materials & palette

| Surface        | Colors (Theme)                          | Notes |
|----------------|-----------------------------------------|-------|
| Table backdrop | `#c7c1b4` (local in ContentView)        | warm neutral behind the board |
| Maple frame    | `woodLight → woodDark`, diagonal        | board frame, toolbar, status bar |
| Wood chrome    | `Theme.wood` (`woodMid → woodDark`)     | toolbar + status bar, +6% black wash |
| Sage felt      | `feltLight → feltDark`, **radial** at 50%/32% | the play surface |
| Cream / paper  | `Theme.cream`, `Theme.paper`            | buttons, advisor panel |
| Ink            | `ink` / `inkDeep` / `inkLabel` / `subtle` | text, darkest on cream, `inkDeep` on wood |

**Players** are indexed `[0]=You/blue, [1]=Opp/red`, always. Each has a 4-stop
gloss ramp: `pHi` (highlight) → `pMid` → `pLo` (core) for radial pieces, plus
`pFlat` for flat swatches and `pWallHi/pWallLo` for walls.

**Accents:** `accent` orange (`#c56a3f`) = brand + Suggest + suggested-move card.
Green (`goodHi/goodMid/goodDark`) = evaluation-in-your-favour + the on-board
suggestion. Red `bad` = against-you / illegal.

## Typography
- **Headings / numbers → serif** (`.system(design: .serif)`), standing in for
  *Bitter*. Brand title, wall counts, eval value, suggested-move text.
- **Everything else → default system sans**, standing in for *Libre Franklin*.
- **Labels / eyebrows**: UPPERCASE, `tracking` 1.6–2.4, `subtle` or `inkDeep`,
  size 11, semibold/bold. Used for every section header and toolbar field label.

If the real fonts get bundled later, swap the `.serif` design + default sans for
Bitter / Libre Franklin and keep the same weights and tracking.

## Depth language
Consistent light-from-top-left:
- **Raised** (buttons, pieces, walls): light top edge (white overlay / `pHi`),
  a solid colored **bottom lip** offset `+2px` (`woodEdge` / `accentLo`), and a
  soft drop shadow below. Pressed = translate down 2px, lose the lip.
- **Inset** (cream toolbar fields, eval track): darker fill, inner top shadow.
- Felt tiles: subtle top-light→bottom-dark gradient, rounded ~12% of a cell.

## Board (`BoardView`)
The entire board is one `Canvas` so frame, felt, coordinate labels and pieces
stay pixel-aligned. Felt is a square inset by a gutter: `padL 0.055` (left, holds
row numbers) / `padT 0.03` (top) with `feltFrac 0.915`; columns/rows labels live
in the left & bottom gutters (`inkLabel`). Rows read **1 (top) → 9 (bottom)**,
cols **A → I** — cosmetic only; engine notation stays `r/c` ints.

- **Goal washes:** top row = blue fade (You finish top), bottom = red fade.
- **Pawns:** radial-gloss disk (highlight offset to 35%/28%), white 1.5px ring,
  ambient glow, drop shadow, white YOU/OPP label.
- **Walls:** gloss gradient *across* the bar, round caps, drop shadow, colored by
  owner (`pWallHi/Lo`).
- **Suggestion:** pulsing green cell (border + center dot) or dashed green wall.
- **Hover:** legal cell = translucent green, illegal = faint black; wall = green
  if legal else red.

Captions above/below the board — "▲ YOU FINISH HERE" (blue) / "▼ OPP FINISHES
HERE" (red), uppercase tracked — flip with the human's side.

## Motion (keep it subtle)
Driven by `TimelineView(.animation)` feeding a time `t` into the Canvas:
- **Float:** the side-to-move pawn bobs ±3.5% of a cell, ~3s period.
- **Active ring:** a soft ring around the side-to-move pawn pulses, ~2.2s.
- **Suggestion pulse:** green cell fill/border breathes, ~2.4s.
Rule of thumb: slow (2–3s), low-amplitude, never distract from reading the board.
New animations should use the same `sin(t · 2π / period)` idiom.

## Advisor panel (`SidePanelView`)
Cream `paper` gradient, 1px `woodDark` left border, 340pt wide. Order: brand
(serif, "Advisor" in orange) → uppercase subtitle → **turn pill** (capsule tinted
15% of the side's color) → hairline → **walls in hand** (color dot + 10 gradient
pips + serif count per side) → hairline → **evaluation** (serif signed value +
gradient capsule bar + plain-language verdict) → **suggested-move card** (orange
0.10 fill, 0.5 orange border, orange chip + serif move text) → hairline →
**legend**. Hairlines are a `woodDark` gradient that fades at both ends.

## Toolbar / buttons
Wood strip. Field label (uppercase, tracked, `inkDeep`) + native control. Buttons
use `WoodButton` (cream raised key); Suggest uses `WoodButton(accent: true)`
(orange, white text) and is prefixed ✦. Hints is a green `.switch` toggle.

## Adding to the UI — checklist
1. Color from `Theme`, not literals.
2. Serif for headings/numbers, uppercase-tracked for labels, sans otherwise.
3. Respect light-from-top-left depth (lip + shadow for raised, inner shadow for inset).
4. Any motion via `TimelineView` + slow low-amplitude `sin`.
5. Keep player indexing `0=You/blue, 1=Opp/red` everywhere.
