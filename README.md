# Barricade Advisor — native macOS app

Swift/SwiftUI port of the Python Barricade / Quoridor best-move engine. Same
rules, same minimax + alpha-beta search (transposition table, iterative
deepening, wall-candidate pruning), rebuilt as a native, optimized Mac app.

## Layout
- `Sources/QuoridorCore/` — pure logic, no UI.
  - `Board.swift` — `State` value struct; walls packed as `UInt64` **bitboards**
    (64 slots) so `blocked()` is a bit test and copies are cheap. `pawnMoves`,
    `bfsDist`, `wallPlacements`, `apply`, `winner`, `legalMoves`.
  - `Engine.swift` — `Engine` class: `evaluate`, candidate-wall pruning,
    move ordering, alpha-beta with `[State: TTEntry]` transposition table,
    `bestMove` (iterative deepening under a time budget).
- `Sources/BarricadeAdvisor/` — SwiftUI app (`Canvas` board, side panel,
  hover preview, async engine off the main thread). Modes, difficulty, side,
  hints, undo/reset/rematch — feature-parity with the old Tk GUI.
- `Tests/` — port of `test_board.py` (`swift test`).
- `Tools/make_icon.swift` — renders the app icon.
- `build_app.sh` — builds `Barricade Advisor.app` (binary + `.icns` + Info.plist).

## Build & run
```
swift test                 # rules + engine sanity (all pass)
swift run -c release        # run from CLI
./build_app.sh              # produce "Barricade Advisor.app"
open "Barricade Advisor.app"
```

Drag `Barricade Advisor.app` to `/Applications` to keep it. No dependencies —
pure Swift + SwiftUI.

## Play
- Hover a square → preview a move; click to enter it.
- Hover near a grid line → preview a barricade (green legal, red illegal); click
  to place. Orientation is inferred from where you hover.
- Toolbar sets mode (vs engine / analysis), difficulty, your side, hints.
- The green overlay is the engine's suggestion — it is never auto-played.
