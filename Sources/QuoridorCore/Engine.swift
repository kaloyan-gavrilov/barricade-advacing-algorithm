// Search engine for Barricade / Quoridor.
//
// Minimax + alpha-beta with a transposition table, tempo-aware evaluation and
// wall-candidate pruning (only walls touching either player's shortest path,
// plus walls hugging a pawn) — cutting the branching factor from ~130 to ~30.

import Foundation

public let WIN = 10_000.0

// ---------------------------------------------------------------------------
// Evaluation
// ---------------------------------------------------------------------------
public func evaluate(_ s: State, _ me: Int) -> Double {
    let opp = 1 - me
    let myD = bfsDist(s, me)
    let oppD = bfsDist(s, opp)
    if myD == INF { return -WIN }
    if oppD == INF { return WIN }

    // Core race term: be closer to my goal than the opponent to theirs.
    var score = Double(oppD - myD)
    // Tempo: side to move gets the next step, worth ~half a step.
    score += s.turn == me ? 0.5 : -0.5
    // Walls in reserve, worth more early, tapering toward the end.
    let closest = min(myD, oppD)
    let phase = max(0.0, min(1.0, Double(closest) / 8.0))
    let wallVal = 0.10 + 0.20 * phase
    score += wallVal * Double(s.wallsLeft[me] - s.wallsLeft[opp])
    return score
}

// ---------------------------------------------------------------------------
// Shortest-path reconstruction + wall candidate pruning
// ---------------------------------------------------------------------------
func bfsPath(_ s: State, _ player: Int) -> [Pos] {
    let start = s.pawns[player]
    let goalRow = GOAL_ROW[player]
    if start.r == goalRow { return [] }
    var prev = [Pos: Pos]()
    var q = [Pos]([start]); q.reserveCapacity(N * N)
    var head = 0
    var end: Pos? = nil
    var visited = Set<Pos>([start])
    while head < q.count {
        let cell = q[head]; head += 1
        if cell.r == goalRow { end = cell; break }
        neighbors(s, cell) { nb in
            if visited.insert(nb).inserted {
                prev[nb] = cell
                q.append(nb)
            }
        }
    }
    guard var cur = end else { return [] }
    var path: [Pos] = []
    while true {
        path.append(cur)
        guard let p = prev[cur] else { break }
        cur = p
    }
    path.reverse()
    return path
}

func blockingSlots(_ frm: Pos, _ to: Pos) -> [(Kind, Int, Int)] {
    let dr = to.r - frm.r
    var out: [(Kind, Int, Int)] = []
    if dr != 0 {                          // vertical step -> horizontal wall
        let top = min(frm.r, to.r)
        for c in [frm.c, frm.c - 1] { out.append((.h, top, c)) }
    } else {                              // horizontal step -> vertical wall
        let left = min(frm.c, to.c)
        for r in [frm.r, frm.r - 1] { out.append((.v, r, left)) }
    }
    return out
}

func candidateWalls(_ s: State) -> [Move] {
    if s.wallsLeft[s.turn] <= 0 { return [] }
    var slots = Set<Move>()  // reuse Move as a hashable (kind,r,c) carrier
    for p in 0..<2 {
        let path = bfsPath(s, p)
        if path.count >= 2 {
            for i in 0..<(path.count - 1) {
                for (k, r, c) in blockingSlots(path[i], path[i + 1]) {
                    slots.insert(.wall(k, r, c))
                }
            }
        }
        // Walls hugging each pawn (all four surrounding edges).
        let pr = s.pawns[p].r, pc = s.pawns[p].c
        for (k, r, c) in [(Kind.h, pr - 1, pc), (.h, pr, pc), (.v, pr, pc - 1), (.v, pr, pc)] {
            slots.insert(.wall(k, r, c))
        }
    }
    var out: [Move] = []
    for mv in slots {
        guard case let .wall(kind, r, c) = mv else { continue }
        if !(r >= 0 && r < W && c >= 0 && c < W) { continue }
        if wallConflicts(s, kind, r, c) { continue }
        if !wallKeepsPaths(s, kind, r, c) { continue }
        out.append(mv)
    }
    return out
}

func orderedMoves(_ s: State, _ ttMove: Move? = nil) -> [Move] {
    let me = s.turn
    let opp = 1 - me
    let myD = bfsDist(s, me)
    let oppD = bfsDist(s, opp)

    var scored: [(Double, Move)] = []
    for p in pawnMoves(s) {
        let mv = Move.move(p.r, p.c)
        let ns = apply(s, mv)
        let gain = myD - bfsDist(ns, me)
        scored.append((200.0 + Double(gain), mv))
    }
    for mv in candidateWalls(s) {
        let ns = apply(s, mv)
        let gain = bfsDist(ns, opp) - oppD
        scored.append((Double(gain), mv))
    }
    scored.sort { $0.0 > $1.0 }
    var moves = scored.map { $0.1 }
    if let tt = ttMove, let idx = moves.firstIndex(of: tt) {
        moves.remove(at: idx)
        moves.insert(tt, at: 0)
    }
    return moves
}

// ---------------------------------------------------------------------------
// Alpha-beta with transposition table
// ---------------------------------------------------------------------------
private enum Flag { case exact, lower, upper }
private struct TTEntry { var depth: Int; var val: Double; var flag: Flag; var move: Move? }

struct Timeout: Error {}

public final class Engine {
    private var tt: [State: TTEntry] = [:]

    public init() {}

    private func search(_ s: State, _ depth: Int, _ alpha0: Double, _ beta0: Double,
                        _ me: Int, _ deadline: Double, _ ply: Int) throws -> Double {
        if let w = winner(s) { return w == me ? (WIN - Double(ply)) : (-WIN + Double(ply)) }
        if depth == 0 { return evaluate(s, me) }
        if now() > deadline { throw Timeout() }

        var alpha = alpha0, beta = beta0
        var ttMove: Move? = nil
        if let e = tt[s] {
            if e.depth >= depth {
                switch e.flag {
                case .exact: return e.val
                case .lower: alpha = max(alpha, e.val)
                case .upper: beta = min(beta, e.val)
                }
                if alpha >= beta { return e.val }
            }
            ttMove = e.move
        }

        let maximizing = s.turn == me
        var best = maximizing ? -Double.infinity : Double.infinity
        var bestMove: Move? = nil
        for mv in orderedMoves(s, ttMove) {
            let val = try search(apply(s, mv), depth - 1, alpha, beta, me, deadline, ply + 1)
            if maximizing {
                if val > best { best = val; bestMove = mv }
                alpha = max(alpha, best)
            } else {
                if val < best { best = val; bestMove = mv }
                beta = min(beta, best)
            }
            if alpha >= beta { break }
        }

        let flag: Flag = best <= alpha0 ? .upper : (best >= beta0 ? .lower : .exact)
        tt[s] = TTEntry(depth: depth, val: best, flag: flag, move: bestMove)
        return best
    }

    /// Return (move, eval) for the side to move via iterative deepening.
    public func bestMove(_ s: State, timeBudget: Double = 2.0, maxDepth: Int = 8) -> (Move?, Double) {
        let me = s.turn
        let deadline = now() + timeBudget
        tt.removeAll(keepingCapacity: true)

        var rootMoves = orderedMoves(s)
        if rootMoves.isEmpty { return (nil, evaluate(s, me)) }

        var bestMv = rootMoves[0]
        var bestVal = -Double.infinity

        for depth in 1...maxDepth {
            var alpha = -Double.infinity
            let beta = Double.infinity
            var curBestMv: Move? = nil
            var curBestVal = -Double.infinity
            do {
                for mv in rootMoves {
                    let val = try search(apply(s, mv), depth - 1, alpha, beta, me, deadline, 1)
                    if val > curBestVal { curBestVal = val; curBestMv = mv }
                    alpha = max(alpha, val)
                }
            } catch {
                break  // timeout: keep the best from the last completed depth
            }
            if let mv = curBestMv {
                bestMv = mv; bestVal = curBestVal
                // Search the best move first next iteration.
                if let idx = rootMoves.firstIndex(of: mv) {
                    rootMoves.remove(at: idx); rootMoves.insert(mv, at: 0)
                }
            }
            if abs(bestVal) >= WIN - 100 { break }  // forced result found
        }
        return (bestMv, bestVal)
    }
}

@inline(__always) private func now() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
}
