# Barricade / Quoridor best-move engine — native macOS app

**What:** Swift + SwiftUI Mac app. Input the moves both players made on
barricade.gg (a Quoridor clone); the engine suggests the best move for the side
to play. Ported from an earlier Python/numpy prototype.

## Layout (SwiftPM package, root)
- `Sources/QuoridorCore/` — rules & search, no UI.
  - `Board.swift` — `State` value struct (pawns, `wallsH`/`wallsV` as **UInt64
    bitboards** over 64 slots, `wallsLeft`, `turn`, cosmetic `ownerH`/`ownerV`).
    All movement goes through **`blocked()`** (single source of truth, shared by
    move-gen and BFS). Key fns: `pawnMoves` (incl. straight + diagonal jumps),
    `bfsDist` (BFS shortest path to goal, returns `INF` sentinel), `wallPlacements`
    (rejects overlap/cross via `wallConflicts` + no-cutoff via `wallKeepsPaths`),
    `apply`, `winner`, `legalMoves`.
  - `Engine.swift` — `Engine` class: minimax + alpha-beta, iterative deepening
    (`bestMove`), `[State: TTEntry]` transposition table, candidate-wall pruning,
    move ordering. Eval = `oppDist - myDist` + tempo + wall-reserve term.
- `Sources/BarricadeAdvisor/` — SwiftUI app.
  - `App.swift` (@main), `ContentView.swift` (toolbar/status), `BoardView.swift`
    (`Canvas` board, hover + tap picking), `SidePanelView.swift`, `Theme.swift`
    (palette; `typealias BoardState = QuoridorCore.State` to dodge SwiftUI.State),
    `GameModel.swift` (`@MainActor ObservableObject`; engine runs on a detached
    Task, stale results dropped by generation counter). Suggestion drawn in
    green, never auto-played.
- `Tests/QuoridorCoreTests/` — rules + engine sanity checks.
- `Tools/make_icon.swift` — renders the app icon PNG.
- `build_app.sh` — builds `Barricade Advisor.app` (release binary + `.icns` +
  Info.plist, ad-hoc signed).

## Conventions
- Coords `Pos(row, col)`, 0..8. Player 0 = start `(0,4)`, goal row 8, drawn at
  BOTTOM (blue). Player 1 = start `(8,4)`, goal row 0, drawn at TOP (red).
- Moves are the `Move` enum: `.move(r, c)` or `.wall(.h|.v, r, c)`. Wall slot
  `(r,c)` = intersection anchor; h spans cols c,c+1 on edge below row r; v spans
  rows r,r+1 on edge right of col c. Bit index = `r*8 + c`.
- `State` is a value type — copied by assignment; `apply` never mutates its
  input. Owner masks are cosmetic and excluded from `Hashable`/`Equatable` so the
  TT keys positions identically regardless of who placed a wall.
- Board render flips vertically: board y-up (row 0 bottom) → screen y-down.

## Run
```
swift test                  # rules + engine sanity (all must pass)
swift run -c release         # run app from CLI
./build_app.sh               # produce "Barricade Advisor.app"
```
No external deps — pure Swift + SwiftUI. Requires macOS 13+.

## Gotchas
- If move-gen and BFS ever disagree, the bug is in `blocked()` — fix it there,
  not in callers.
- Branching factor is large (~130) but the engine prunes to candidate walls
  (~30). Keep opponent time budgets small; don't push `maxDepth` past 4 for the
  interactive tiers.
- `State` clashes with SwiftUI's `@State`. In UI files use the `BoardState`
  typealias, never bare `State`.
