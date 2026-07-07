// Board state and rules for Barricade / Quoridor.
//
// Coordinate system
// -----------------
// Cells are (row, col) with row, col in 0..8.
// Player 0 starts at (0, 4) and races to reach row 8 (its goal row).
// Player 1 starts at (8, 4) and races to reach row 0 (its goal row).
//
// Walls occupy the edges *between* cells and are two cells long. They live in
// two 8x8 boolean grids, here packed as UInt64 bitboards (bit r*8+c):
//
//   wallsH[r, c]  horizontal wall on the edge between rows r and r+1, spanning
//                 columns c and c+1. Blocks vertical movement between
//                 (r,c)<->(r+1,c) and (r,c+1)<->(r+1,c+1).
//
//   wallsV[r, c]  vertical wall on the edge between cols c and c+1, spanning
//                 rows r and r+1. Blocks horizontal movement between
//                 (r,c)<->(r,c+1) and (r+1,c)<->(r+1,c+1).

import Foundation

public let N = 9        // board is N x N cells
public let W = N - 1    // walls live on an (N-1) x (N-1) slot grid
public let GOAL_ROW = [8, 0]              // goal row for player 0, player 1
public let START = [Pos(0, 4), Pos(8, 4)] // start cell for player 0, player 1
public let INF = 1 << 20                  // "no path" sentinel distance

public struct Pos: Hashable, Sendable {
    public var r: Int
    public var c: Int
    @inline(__always) public init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}

public enum Kind: Sendable { case h, v }

public enum Move: Hashable, Sendable {
    case move(Int, Int)        // move / jump pawn to (r, c)
    case wall(Kind, Int, Int)  // place a wall at slot (r, c)

    // Kind is not Hashable-synthesizable across all toolchains cheaply; hand-roll.
    public static func == (a: Move, b: Move) -> Bool {
        switch (a, b) {
        case let (.move(r0, c0), .move(r1, c1)): return r0 == r1 && c0 == c1
        case let (.wall(k0, r0, c0), .wall(k1, r1, c1)):
            return k0 == k1 && r0 == r1 && c0 == c1
        default: return false
        }
    }
    public func hash(into h: inout Hasher) {
        switch self {
        case let .move(r, c): h.combine(0); h.combine(r); h.combine(c)
        case let .wall(k, r, c):
            h.combine(1); h.combine(k == .h ? 0 : 1); h.combine(r); h.combine(c)
        }
    }
}

@inline(__always) func bit(_ r: Int, _ c: Int) -> UInt64 { UInt64(1) << (r * W + c) }

public struct State: Hashable, Sendable {
    public var pawns: [Pos]        // [p0, p1]
    public var wallsH: UInt64      // horizontal walls, bit r*8+c
    public var wallsV: UInt64      // vertical walls
    public var ownerH: UInt64      // bit set => player 1 placed it (only where wall present)
    public var ownerV: UInt64
    public var wallsLeft: [Int]    // [p0, p1]
    public var turn: Int

    public init(pawns: [Pos] = START,
                wallsH: UInt64 = 0, wallsV: UInt64 = 0,
                ownerH: UInt64 = 0, ownerV: UInt64 = 0,
                wallsLeft: [Int] = [10, 10], turn: Int = 0) {
        self.pawns = pawns
        self.wallsH = wallsH; self.wallsV = wallsV
        self.ownerH = ownerH; self.ownerV = ownerV
        self.wallsLeft = wallsLeft; self.turn = turn
    }

    // Owner is cosmetic only — exclude from identity so the transposition table
    // treats positions reached by either player identically.
    public static func == (a: State, b: State) -> Bool {
        a.pawns == b.pawns && a.wallsH == b.wallsH && a.wallsV == b.wallsV
            && a.wallsLeft == b.wallsLeft && a.turn == b.turn
    }
    public func hash(into h: inout Hasher) {
        h.combine(pawns); h.combine(wallsH); h.combine(wallsV)
        h.combine(wallsLeft); h.combine(turn)
    }

    @inline(__always) public func hasH(_ r: Int, _ c: Int) -> Bool {
        (r >= 0 && r < W && c >= 0 && c < W) && (wallsH & bit(r, c)) != 0
    }
    @inline(__always) public func hasV(_ r: Int, _ c: Int) -> Bool {
        (r >= 0 && r < W && c >= 0 && c < W) && (wallsV & bit(r, c)) != 0
    }
}

@inline(__always) public func onBoard(_ r: Int, _ c: Int) -> Bool {
    r >= 0 && r < N && c >= 0 && c < N
}

// Is there a horizontal wall on the edge below row top_r at column c?
// A slot (top_r, k) covers columns k and k+1, so column c is covered by k=c or k=c-1.
@inline(__always) func hBetween(_ s: State, _ topR: Int, _ c: Int) -> Bool {
    s.hasH(topR, c) || s.hasH(topR, c - 1)
}

// Is there a vertical wall on the edge right of column left_c at row r?
@inline(__always) func vBetween(_ s: State, _ r: Int, _ leftC: Int) -> Bool {
    s.hasV(r, leftC) || s.hasV(r - 1, leftC)
}

/// True if the orthogonal step frm -> to is blocked by a wall. Single source of
/// truth for wall-vs-movement; used by both move generation and BFS.
@inline(__always)
public func blocked(_ s: State, _ frm: Pos, _ to: Pos) -> Bool {
    let dr = to.r - frm.r, dc = to.c - frm.c
    if dr == 1 && dc == 0 { return hBetween(s, frm.r, frm.c) }   // down
    if dr == -1 && dc == 0 { return hBetween(s, to.r, to.c) }    // up
    if dr == 0 && dc == 1 { return vBetween(s, frm.r, frm.c) }   // right
    if dr == 0 && dc == -1 { return vBetween(s, to.r, to.c) }    // left
    return true                                                  // not a single step
}

private let DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]

/// Reachable orthogonal neighbors of `cell`, respecting walls (ignores pawns).
@inline(__always)
public func neighbors(_ s: State, _ cell: Pos, _ body: (Pos) -> Void) {
    for (dr, dc) in DIRS {
        let nr = cell.r + dr, nc = cell.c + dc
        if onBoard(nr, nc) {
            let nb = Pos(nr, nc)
            if !blocked(s, cell, nb) { body(nb) }
        }
    }
}

/// Legal pawn destinations for the side to move, including jumps.
public func pawnMoves(_ s: State) -> [Pos] {
    let me = s.turn
    let opp = 1 - me
    let myCell = s.pawns[me]
    let oppCell = s.pawns[opp]
    var dests: [Pos] = []

    neighbors(s, myCell) { nb in
        if nb != oppCell { dests.append(nb); return }
        // Opponent adjacent -> jump rules.
        let dr = oppCell.r - myCell.r, dc = oppCell.c - myCell.c
        let straight = Pos(oppCell.r + dr, oppCell.c + dc)
        if onBoard(straight.r, straight.c) && !blocked(s, oppCell, straight) {
            dests.append(straight)                       // straight jump
        } else {
            let sides = dr != 0 ? [(0, 1), (0, -1)] : [(1, 0), (-1, 0)]
            for (sdr, sdc) in sides {
                let diag = Pos(oppCell.r + sdr, oppCell.c + sdc)
                if onBoard(diag.r, diag.c) && !blocked(s, oppCell, diag) {
                    dests.append(diag)
                }
            }
        }
    }

    // Dedup while preserving order.
    var seen = Set<Pos>()
    var out: [Pos] = []
    for d in dests where seen.insert(d).inserted { out.append(d) }
    return out
}

/// Shortest number of steps from player's pawn to its goal row (ignores the
/// opponent pawn, standard Quoridor distance). Returns INF if no path.
public func bfsDist(_ s: State, _ player: Int) -> Int {
    let start = s.pawns[player]
    let goalRow = GOAL_ROW[player]
    if start.r == goalRow { return 0 }
    var seen = [Bool](repeating: false, count: N * N)
    seen[start.r * N + start.c] = true
    var q = [(Pos, Int)]()
    q.reserveCapacity(N * N)
    q.append((start, 0))
    var head = 0
    while head < q.count {
        let (cell, d) = q[head]; head += 1
        var found = false
        neighbors(s, cell) { nb in
            if found { return }
            let idx = nb.r * N + nb.c
            if seen[idx] { return }
            if nb.r == goalRow { found = true; return }
            seen[idx] = true
            q.append((nb, d + 1))
        }
        if found { return d + 1 }
    }
    return INF
}

/// True if a wall at (kind, r, c) overlaps or crosses an existing wall.
public func wallConflicts(_ s: State, _ kind: Kind, _ r: Int, _ c: Int) -> Bool {
    if !(r >= 0 && r < W && c >= 0 && c < W) { return true }
    if kind == .h {
        if s.hasH(r, c) { return true }                       // exact overlap
        if c - 1 >= 0 && s.hasH(r, c - 1) { return true }     // left neighbor
        if c + 1 < W && s.hasH(r, c + 1) { return true }      // right neighbor
        if s.hasV(r, c) { return true }                       // crossing vertical
    } else {
        if s.hasV(r, c) { return true }
        if r - 1 >= 0 && s.hasV(r - 1, c) { return true }
        if r + 1 < W && s.hasV(r + 1, c) { return true }
        if s.hasH(r, c) { return true }                       // crossing horizontal
    }
    return false
}

@inline(__always)
func placeWall(_ s: State, _ kind: Kind, _ r: Int, _ c: Int) -> State {
    var ns = s
    if kind == .h { ns.wallsH |= bit(r, c) } else { ns.wallsV |= bit(r, c) }
    return ns
}

/// True if placing this wall leaves BOTH players a route to their goal.
public func wallKeepsPaths(_ s: State, _ kind: Kind, _ r: Int, _ c: Int) -> Bool {
    let ns = placeWall(s, kind, r, c)
    return bfsDist(ns, 0) != INF && bfsDist(ns, 1) != INF
}

/// All legal wall moves for the side to move.
public func wallPlacements(_ s: State) -> [Move] {
    if s.wallsLeft[s.turn] <= 0 { return [] }
    var out: [Move] = []
    for kind in [Kind.h, Kind.v] {
        for r in 0..<W {
            for c in 0..<W {
                if wallConflicts(s, kind, r, c) { continue }
                if !wallKeepsPaths(s, kind, r, c) { continue }
                out.append(.wall(kind, r, c))
            }
        }
    }
    return out
}

/// All legal moves (pawn moves + wall placements) for the side to move.
public func legalMoves(_ s: State) -> [Move] {
    var moves = pawnMoves(s).map { Move.move($0.r, $0.c) }
    moves.append(contentsOf: wallPlacements(s))
    return moves
}

/// Return the new state after applying `move`. Does not mutate `s`.
public func apply(_ s: State, _ move: Move) -> State {
    switch move {
    case let .move(r, c):
        var ns = s
        ns.pawns[ns.turn] = Pos(r, c)
        ns.turn = 1 - ns.turn
        return ns
    case let .wall(kind, r, c):
        var ns = placeWall(s, kind, r, c)
        if kind == .h {
            if ns.turn == 1 { ns.ownerH |= bit(r, c) } else { ns.ownerH &= ~bit(r, c) }
        } else {
            if ns.turn == 1 { ns.ownerV |= bit(r, c) } else { ns.ownerV &= ~bit(r, c) }
        }
        ns.wallsLeft[ns.turn] -= 1
        ns.turn = 1 - ns.turn
        return ns
    }
}

/// Return 0 or 1 if that player reached its goal row, else nil.
public func winner(_ s: State) -> Int? {
    for p in 0..<2 where s.pawns[p].r == GOAL_ROW[p] { return p }
    return nil
}
