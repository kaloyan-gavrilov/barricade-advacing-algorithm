import SwiftUI
import QuoridorCore

// Opponent difficulty. `blunder` = chance per move of playing a random legal
// move instead of the engine's pick (weakens the easy tiers).
struct Level {
    let name: String
    let budget: Double
    let depth: Int
    let blunder: Double
}

let LEVELS: [Level] = [
    Level(name: "Easy",       budget: 0.2,  depth: 1, blunder: 0.40),
    Level(name: "Medium",    budget: 0.8,  depth: 2, blunder: 0.15),
    Level(name: "Hard",       budget: 3.0,  depth: 4, blunder: 0.0),
    Level(name: "Impossible", budget: 12.0, depth: 8, blunder: 0.0),
]

enum GameMode: String, CaseIterable, Identifiable {
    case vs, analysis
    var id: String { rawValue }
    var label: String { self == .vs ? "Play vs Engine" : "Analysis (both sides)" }
}

// Hover selection over the board.
enum Hover: Equatable {
    case cell(Int, Int)
    case wall(Kind, Int, Int)
}

// barricade.gg convention: red (player 1) always makes the opening move.
let FIRST_PLAYER = 1

let HINT_BUDGET = 2.5
let HINT_DEPTH = 6

@MainActor
final class GameModel: ObservableObject {
    @Published var history: [BoardState]
    @Published var suggestion: Move? = nil
    @Published var suggVal: Double = 0.0
    @Published var status = "Your move. Hover to preview, click to enter."
    @Published var hover: Hover? = nil

    @Published var mode: GameMode = .vs
    @Published var human = 0            // side the human plays (0/1)
    @Published var showHints = true
    @Published var level = 2            // index into LEVELS
    @Published var aiBusy = false       // block input while engine thinks

    @Published var scoreYou = 0
    @Published var scoreOpp = 0

    private var gen = 0                 // bumped on every position/settings change
    private var recorded = false
    private var thinkTimer: Timer? = nil
    private var thinkBase: String? = nil
    private var thinkDots = 0

    var state: BoardState { history.last! }

    init() {
        history = [BoardState(turn: FIRST_PLAYER)]
        advance()
    }

    // MARK: - state helpers
    private func newState() -> BoardState { BoardState(turn: FIRST_PLAYER) }

    private func engineTurn() -> Bool {
        mode == .vs && winner(state) == nil && state.turn != human
    }

    func settingsChanged() {
        objectWillChange.send()
        if !aiBusy { advance() }
    }

    // MARK: - think pipeline
    func advance() {
        gen += 1
        suggestion = nil
        hover = nil

        if let w = winner(state) {
            let youWon = (w == human)
            if !recorded {
                recorded = true
                if youWon { scoreYou += 1 } else { scoreOpp += 1 }
            }
            let who = youWon ? "YOU" : "OPP"
            status = "\(who) win! Score you \(scoreYou)-\(scoreOpp) opp. Rematch (G) to play again."
            suggVal = evaluate(state, human)
            return
        }

        if engineTurn() {
            startAI()
            return
        }

        if !showHints {
            suggVal = evaluate(state, state.turn)
            status = "Hints off — enable hints to show the suggestion."
            return
        }
        startHint()
    }

    private func setThinking(_ base: String) {
        thinkBase = base
        thinkDots = 0
        thinkTimer?.invalidate()
        thinkTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickThink() }
        }
    }
    private func tickThink() {
        guard let base = thinkBase else { return }
        thinkDots = (thinkDots + 1) % 4
        status = base + String(repeating: ".", count: thinkDots)
    }
    private func stopThinking() {
        thinkBase = nil
        thinkTimer?.invalidate()
        thinkTimer = nil
    }

    private func startHint() {
        let g = gen
        let st = state
        setThinking("Thinking about your best move")
        Task.detached(priority: .userInitiated) {
            let eng = Engine()
            let (mv, val) = eng.bestMove(st, timeBudget: HINT_BUDGET, maxDepth: HINT_DEPTH)
            await MainActor.run { self.finishHint(g, mv, val) }
        }
    }
    private func finishHint(_ g: Int, _ mv: Move?, _ val: Double) {
        guard g == gen else { return }   // position moved on — drop stale hint
        stopThinking()
        suggestion = mv
        suggVal = val
        let side = state.turn == human ? "YOU" : "OPP"
        status = "\(side) to move - suggestion: \(Self.notation(mv))"
    }

    private func startAI() {
        aiBusy = true
        let g = gen
        let st = state
        let cfg = LEVELS[level]
        setThinking("Engine (\(cfg.name)) thinking")
        Task.detached(priority: .userInitiated) {
            let mv: Move?
            if cfg.blunder > 0 && Double.random(in: 0..<1) < cfg.blunder {
                mv = legalMoves(st).randomElement()
            } else {
                mv = Engine().bestMove(st, timeBudget: cfg.budget, maxDepth: cfg.depth).0
            }
            await MainActor.run { self.finishAI(g, mv) }
        }
    }
    private func finishAI(_ g: Int, _ mv: Move?) {
        aiBusy = false
        stopThinking()
        guard g == gen else { return }
        if let mv = mv { history.append(apply(state, mv)) }
        advance()
    }

    // MARK: - notation
    static func notation(_ mv: Move?) -> String {
        guard let mv = mv else { return "-" }
        switch mv {
        case let .move(r, c): return "move to r\(r) c\(c)"
        case let .wall(k, r, c):
            return "\(k == .h ? "horizontal" : "vertical") barricade at slot (\(r),\(c))"
        }
    }

    // MARK: - input
    private func push(_ move: Move) {
        history.append(apply(state, move))
        advance()
    }

    func tryMove(_ r: Int, _ c: Int) {
        if pawnMoves(state).contains(Pos(r, c)) {
            push(.move(r, c))
        } else {
            status = "Illegal pawn move to r\(r) c\(c)."
        }
    }

    func tryWall(_ kind: Kind, _ r: Int, _ c: Int) {
        if state.wallsLeft[state.turn] <= 0 {
            status = "No barricades left for the side to move."
        } else if wallConflicts(state, kind, r, c) {
            status = "Barricade at slot (\(r),\(c)) overlaps or crosses another."
        } else if !wallKeepsPaths(state, kind, r, c) {
            status = "Barricade at slot (\(r),\(c)) would cut off a player's path."
        } else {
            push(.wall(kind, r, c))
        }
    }

    func wallOK(_ kind: Kind, _ r: Int, _ c: Int) -> Bool {
        state.wallsLeft[state.turn] > 0
            && !wallConflicts(state, kind, r, c)
            && wallKeepsPaths(state, kind, r, c)
    }

    var inputLocked: Bool { aiBusy || engineTurn() || winner(state) != nil }

    // MARK: - actions
    func undo() {
        guard !aiBusy else { return }
        if history.count > 1 { history.removeLast() }
        if mode == .vs && history.count > 1 && state.turn != human {
            history.removeLast()
        }
        if winner(state) == nil { recorded = false }
        advance()
    }
    func reset() {
        guard !aiBusy else { return }
        history = [newState()]
        recorded = false
        advance()
    }
    func rematch() { reset() }
    func resuggest() { guard !aiBusy else { return }; advance() }
    func toggleHints() { showHints.toggle(); if !aiBusy { advance() } }
    func swapSide() {
        guard !aiBusy else { return }
        human = 1 - human
        reset()
    }
}
