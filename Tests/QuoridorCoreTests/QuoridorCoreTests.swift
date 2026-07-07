import XCTest
@testable import QuoridorCore

final class QuoridorCoreTests: XCTestCase {

    func testStartMoves() {
        let s = State()
        XCTAssertEqual(pawnMoves(s).count, 3, "start moves == 3")
    }

    func testCornerMoves() {
        let sc = State(pawns: [Pos(0, 0), Pos(8, 8)])
        XCTAssertEqual(pawnMoves(sc).count, 2, "corner moves == 2")
    }

    func testBfsStart() {
        let s = State()
        XCTAssertEqual(bfsDist(s, 0), 8)
        XCTAssertEqual(bfsDist(s, 1), 8)
    }

    func testStraightJump() {
        let sj = State(pawns: [Pos(3, 4), Pos(4, 4)], turn: 0)
        let m = pawnMoves(sj)
        XCTAssertTrue(m.contains(Pos(5, 4)), "straight jump to (5,4)")
        XCTAssertFalse(m.contains(Pos(4, 4)), "no landing on opponent")
    }

    func testDiagonalJump() {
        var sd = State(pawns: [Pos(3, 4), Pos(4, 4)], turn: 0)
        sd.wallsH |= UInt64(1) << (4 * W + 4)  // wall below (4,4)/(4,5)
        let m = pawnMoves(sd)
        XCTAssertFalse(m.contains(Pos(5, 4)), "no straight jump when blocked")
        XCTAssertTrue(m.contains(Pos(4, 3)), "diagonal jump (4,3)")
        XCTAssertTrue(m.contains(Pos(4, 5)), "diagonal jump (4,5)")
    }

    func testWallBlocksBothWays() {
        var sw = State()
        sw.wallsH |= UInt64(1) << (0 * W + 4)  // wall below row 0 at cols 4,5
        XCTAssertTrue(blocked(sw, Pos(0, 4), Pos(1, 4)))
        XCTAssertTrue(blocked(sw, Pos(1, 4), Pos(0, 4)))
        XCTAssertTrue(blocked(sw, Pos(0, 5), Pos(1, 5)))
        XCTAssertFalse(blocked(sw, Pos(0, 6), Pos(1, 6)))
    }

    func testOverlapCross() {
        var so = State()
        so.wallsH |= UInt64(1) << (3 * W + 3)
        XCTAssertTrue(wallConflicts(so, .h, 3, 3), "exact overlap rejected")
        XCTAssertTrue(wallConflicts(so, .h, 3, 4), "shifted overlap rejected")
        XCTAssertTrue(wallConflicts(so, .h, 3, 2), "shifted overlap rejected2")
        XCTAssertTrue(wallConflicts(so, .v, 3, 3), "crossing vertical rejected")
        XCTAssertFalse(wallConflicts(so, .h, 4, 3), "parallel adjacent ok")
    }

    func testPlacementsNeverCutoff() {
        let sp = State()
        let placements = wallPlacements(sp)
        for case let .wall(kind, r, c) in placements {
            let ns = { var n = sp; if kind == .h { n.wallsH |= UInt64(1) << (r*W+c) } else { n.wallsV |= UInt64(1) << (r*W+c) }; return n }()
            XCTAssertNotEqual(bfsDist(ns, 0), INF)
            XCTAssertNotEqual(bfsDist(ns, 1), INF)
        }
        XCTAssertGreaterThan(placements.count, 100, "many placements from empty board")
    }

    func testBoxedIn() {
        var sb = State(pawns: [Pos(0, 0), Pos(8, 8)])
        sb.wallsV |= UInt64(1) << (0 * W + 0)  // wall right of (0,0)/(1,0)
        var sb2 = sb
        sb2.wallsH |= UInt64(1) << (0 * W + 0)
        XCTAssertEqual(bfsDist(sb2, 0), INF, "boxed-in pawn detected")
        XCTAssertFalse(wallKeepsPaths(sb, .h, 0, 0), "wall_keeps_paths forbids sealing")
    }

    func testEngineLegalAndFast() {
        let eng = Engine()
        let t0 = Date()
        let (mv, val) = eng.bestMove(State(), timeBudget: 2.0)
        let dt = Date().timeIntervalSince(t0)
        XCTAssertNotNil(mv)
        XCTAssertTrue(legalMoves(State()).contains(mv!), "engine move is legal")
        XCTAssertLessThan(dt, 3.0, "engine within time budget")
        if case .move = mv! {} else { XCTFail("opening advances pawn") }
        print("  engine suggested \(mv!) eval=\(val) in \(dt)s")
    }
}
