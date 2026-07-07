import SwiftUI
import QuoridorCore

// The 9x9 board. Board coordinates are (x=col 0..9, y=row 0..9) with row 0 at
// the BOTTOM (player 0 races up), matching barricade.gg. Screen y grows down.
//
// The whole board — maple frame, sage felt, coordinate labels and pieces — is
// painted inside one Canvas so everything stays pixel-aligned (see design.md).
// The felt occupies a square inset from the canvas by a label/frame gutter.
struct BoardView: View {
    @ObservedObject var model: GameModel

    // gutter fractions of the full canvas edge
    private let padL = 0.055, padT = 0.030, feltFrac = 0.915

    var body: some View {
        GeometryReader { geo in
            let full = min(geo.size.width, geo.size.height)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, _ in draw(&ctx, full, t) }
                    .frame(width: full, height: full)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p): model.hover = pick(p, full)
                        case .ended: model.hover = nil
                        }
                    }
                    .gesture(SpatialTapGesture().onEnded { ev in
                        handleTap(ev.location, full)
                    })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - felt geometry (relative to the full square canvas)
    private func geom(_ full: CGFloat) -> (ox: Double, oy: Double, felt: Double, cell: Double) {
        let felt = Double(full) * feltFrac
        return (Double(full) * padL, Double(full) * padT, felt, felt / Double(N))
    }
    // Rect in board coords (x col from left, y row from bottom) -> screen CGRect.
    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ full: CGFloat) -> CGRect {
        let g = geom(full)
        return CGRect(x: g.ox + x * g.cell,
                      y: g.oy + (Double(N) - (y + h)) * g.cell,
                      width: w * g.cell, height: h * g.cell)
    }
    private func point(_ x: Double, _ y: Double, _ full: CGFloat) -> CGPoint {
        let g = geom(full)
        return CGPoint(x: g.ox + x * g.cell, y: g.oy + (Double(N) - y) * g.cell)
    }
    private func toBoard(_ p: CGPoint, _ full: CGFloat) -> (Double, Double) {
        let g = geom(full)
        return ((Double(p.x) - g.ox) / g.cell, Double(N) - (Double(p.y) - g.oy) / g.cell)
    }

    // MARK: - picking
    private func pick(_ p: CGPoint, _ full: CGFloat) -> Hover? {
        guard !model.inputLocked else { return nil }
        let (x, y) = toBoard(p, full)
        guard x >= 0 && x <= Double(N) && y >= 0 && y <= Double(N) else { return nil }
        let gx = min(max(x.rounded(), 1), Double(W))
        let gy = min(max(y.rounded(), 1), Double(W))
        let nearWall = abs(x - gx) < WALL_THR || abs(y - gy) < WALL_THR
        if nearWall {
            let kind: Kind = abs(y - gy) <= abs(x - gx) ? .h : .v
            return .wall(kind, Int(gy) - 1, Int(gx) - 1)
        }
        return .cell(Int(y), Int(x))
    }

    private func handleTap(_ p: CGPoint, _ full: CGFloat) {
        guard !model.inputLocked, let h = pick(p, full) else { return }
        switch h {
        case let .cell(r, c): model.tryMove(r, c)
        case let .wall(k, r, c): model.tryWall(k, r, c)
        }
    }

    // MARK: - drawing
    private func draw(_ ctx: inout GraphicsContext, _ full: CGFloat, _ t: Double) {
        let st = model.state
        let g = geom(full)
        let cell = g.cell

        // maple frame
        let frame = Path(roundedRect: CGRect(x: 0, y: 0, width: Double(full), height: Double(full)),
                         cornerRadius: cell * 0.28)
        ctx.fill(frame, with: .linearGradient(
            Gradient(colors: [Theme.woodLight, Theme.woodDark]),
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: Double(full), y: Double(full))))

        // maple grain — faint horizontal fibers over the frame (felt covers the middle)
        ctx.clip(to: frame)
        var gy = 0.0
        while gy < Double(full) {
            var gp = Path()
            gp.move(to: CGPoint(x: 0, y: gy))
            gp.addLine(to: CGPoint(x: Double(full), y: gy))
            ctx.stroke(gp, with: .color(.black.opacity(0.05)), lineWidth: 1)
            gy += cell * 0.09
        }

        // sage felt
        let feltRect = CGRect(x: g.ox, y: g.oy, width: g.felt, height: g.felt)
        let feltPath = Path(roundedRect: feltRect, cornerRadius: cell * 0.16)
        ctx.fill(feltPath, with: .radialGradient(
            Gradient(colors: [Theme.feltLight, Theme.feltDark]),
            center: CGPoint(x: g.ox + g.felt * 0.5, y: g.oy + g.felt * 0.32),
            startRadius: 0, endRadius: g.felt * 0.72))

        // cell tiles — raised sage pads with a soft bevel
        for r in 0..<N {
            for c in 0..<N {
                let rr = rect(Double(c) + INSET, Double(r) + INSET, 1 - 2 * INSET, 1 - 2 * INSET, full)
                let path = Path(roundedRect: rr, cornerRadius: cell * 0.15)
                // drop shadow into the grout
                var sh = ctx
                sh.addFilter(.shadow(color: .black.opacity(0.28), radius: cell * 0.05, x: 0, y: cell * 0.03))
                sh.fill(path, with: .color(Theme.feltLight.opacity(0.9)))
                // face gradient
                ctx.fill(path, with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.20), Color.black.opacity(0.16)]),
                    startPoint: CGPoint(x: rr.minX, y: rr.minY),
                    endPoint: CGPoint(x: rr.minX, y: rr.maxY)))
                // top highlight edge
                ctx.stroke(path, with: .color(Color.white.opacity(0.14)), lineWidth: 1)
            }
        }

        // goal-row wash: YOU finishes at top (row 8), OPP at bottom (row 0)
        let topWash = rect(0, Double(N - 1), Double(N), 1, full)
        ctx.fill(Path(roundedRect: topWash, cornerRadius: cell * 0.12),
                 with: .linearGradient(Gradient(colors: [Theme.pFlat[0].opacity(0.22), Theme.pFlat[0].opacity(0)]),
                                       startPoint: CGPoint(x: 0, y: topWash.minY), endPoint: CGPoint(x: 0, y: topWash.maxY)))
        let botWash = rect(0, 0, Double(N), 1, full)
        ctx.fill(Path(roundedRect: botWash, cornerRadius: cell * 0.12),
                 with: .linearGradient(Gradient(colors: [Theme.pFlat[1].opacity(0.24), Theme.pFlat[1].opacity(0)]),
                                       startPoint: CGPoint(x: 0, y: botWash.maxY), endPoint: CGPoint(x: 0, y: botWash.minY)))

        drawHover(&ctx, full)

        // legal-move dots for the side to move
        if winner(st) == nil {
            for p in pawnMoves(st) {
                let c = point(Double(p.c) + 0.5, Double(p.r) + 0.5, full)
                let rad = cell * 0.11
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)),
                         with: .color(Theme.pHi[st.turn].opacity(0.5)))
            }
        }

        drawWalls(&ctx, st, full)
        drawPawns(&ctx, st, full, t)
        drawSuggestion(&ctx, full, t)
        drawLabels(&ctx, full)
    }

    private func drawPawns(_ ctx: inout GraphicsContext, _ st: BoardState, _ full: CGFloat, _ t: Double) {
        let cell = geom(full).cell
        let active = winner(st) == nil ? st.turn : -1
        for p in 0..<2 {
            let pos = st.pawns[p]
            let c = point(Double(pos.c) + 0.5, Double(pos.r) + 0.5, full)
            let solid = cell * 0.32

            // active side: single thin static ring — no glow, no pulse
            if p == active {
                let rr = solid + cell * 0.07
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(Theme.pFlat[p].opacity(0.45)),
                           lineWidth: cell * 0.035)
            }

            // flat disk with one soft contact shadow
            var layer = ctx
            layer.addFilter(.shadow(color: .black.opacity(0.22), radius: cell * 0.05, x: 0, y: cell * 0.04))
            let disk = Path(ellipseIn: CGRect(x: c.x - solid, y: c.y - solid, width: solid * 2, height: solid * 2))
            layer.fill(disk, with: .color(Theme.pFlat[p]))
            ctx.stroke(disk, with: .color(.white.opacity(0.85)), lineWidth: 1.5)

            let label = Text(p == 0 ? "YOU" : "OPP")
                .font(.system(size: cell * 0.15, weight: .bold)).foregroundColor(.white)
            ctx.draw(label, at: c)
        }
    }

    private func wallEndpoints(_ kind: Kind, _ r: Int, _ c: Int, _ full: CGFloat) -> (CGPoint, CGPoint) {
        if kind == .h {
            return (point(Double(c) + INSET, Double(r) + 1, full),
                    point(Double(c) + 2 - INSET, Double(r) + 1, full))
        } else {
            return (point(Double(c) + 1, Double(r) + INSET, full),
                    point(Double(c) + 1, Double(r) + 2 - INSET, full))
        }
    }
    private func wallPath(_ kind: Kind, _ r: Int, _ c: Int, _ full: CGFloat) -> Path {
        let (a, b) = wallEndpoints(kind, r, c, full)
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }

    private func drawWalls(_ ctx: inout GraphicsContext, _ st: BoardState, _ full: CGFloat) {
        let lw = geom(full).cell * 0.17
        func gloss(_ kind: Kind, _ r: Int, _ c: Int, _ owner: Int) {
            let (a, b) = wallEndpoints(kind, r, c, full)
            // gradient runs across the bar (perpendicular to its length)
            let g: (CGPoint, CGPoint) = kind == .h
                ? (CGPoint(x: a.x, y: a.y - lw / 2), CGPoint(x: a.x, y: a.y + lw / 2))
                : (CGPoint(x: a.x - lw / 2, y: a.y), CGPoint(x: a.x + lw / 2, y: a.y))
            var layer = ctx
            layer.addFilter(.shadow(color: .black.opacity(0.4), radius: lw * 0.5, x: 0, y: lw * 0.4))
            var p = Path(); p.move(to: a); p.addLine(to: b)
            layer.stroke(p, with: .linearGradient(
                Gradient(colors: [Theme.pWallHi[owner], Theme.pWallLo[owner]]),
                startPoint: g.0, endPoint: g.1),
                style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        for r in 0..<W {
            for c in 0..<W {
                if st.hasH(r, c) {
                    gloss(.h, r, c, (st.ownerH & (UInt64(1) << (r * W + c))) != 0 ? 1 : 0)
                }
                if st.hasV(r, c) {
                    gloss(.v, r, c, (st.ownerV & (UInt64(1) << (r * W + c))) != 0 ? 1 : 0)
                }
            }
        }
    }

    private func drawHover(_ ctx: inout GraphicsContext, _ full: CGFloat) {
        guard let h = model.hover else { return }
        let cell = geom(full).cell
        switch h {
        case let .cell(r, c):
            let legal = pawnMoves(model.state).contains(Pos(r, c))
            let rr = rect(Double(c) + INSET, Double(r) + INSET, 1 - 2 * INSET, 1 - 2 * INSET, full)
            let color = legal ? Theme.goodMid.opacity(0.32) : Color.black.opacity(0.14)
            ctx.fill(Path(roundedRect: rr, cornerRadius: cell * 0.12), with: .color(color))
        case let .wall(k, r, c):
            let ok = model.wallOK(k, r, c)
            let col = (ok ? Theme.goodMid : Theme.bad).opacity(0.55)
            ctx.stroke(wallPath(k, r, c, full), with: .color(col),
                       style: StrokeStyle(lineWidth: cell * 0.14, lineCap: .round))
        }
    }

    private func drawSuggestion(_ ctx: inout GraphicsContext, _ full: CGFloat, _ t: Double) {
        guard let mv = model.suggestion else { return }
        let cell = geom(full).cell
        let ph = 0.5 + 0.5 * sin(t * 2 * .pi / 2.4)
        switch mv {
        case let .move(r, c):
            let rr = rect(Double(c) + INSET, Double(r) + INSET, 1 - 2 * INSET, 1 - 2 * INSET, full)
            let path = Path(roundedRect: rr, cornerRadius: cell * 0.12)
            ctx.fill(path, with: .color(Theme.goodMid.opacity(0.14 + 0.14 * ph)))
            ctx.stroke(path, with: .color(Theme.goodDark), lineWidth: 2 + 1.5 * ph)
            let dot = cell * 0.11
            ctx.fill(Path(ellipseIn: CGRect(x: rr.midX - dot, y: rr.midY - dot, width: dot * 2, height: dot * 2)),
                     with: .color(Theme.goodDark))
        case let .wall(k, r, c):
            ctx.stroke(wallPath(k, r, c, full), with: .color(Theme.goodDark.opacity(0.7 + 0.3 * ph)),
                       style: StrokeStyle(lineWidth: cell * 0.14, lineCap: .round,
                                          dash: [cell * 0.20, cell * 0.10]))
        }
    }

    private func drawLabels(_ ctx: inout GraphicsContext, _ full: CGFloat) {
        let g = geom(full)
        let cols = ["A", "B", "C", "D", "E", "F", "G", "H", "I"]
        for i in 0..<N {
            // rows down the left gutter (1 at top .. 9 at bottom)
            let ry = point(0, Double(i) + 0.5, full).y
            ctx.draw(Text("\(N - i)").font(.system(size: g.cell * 0.17, weight: .semibold))
                        .foregroundColor(Theme.inkLabel),
                     at: CGPoint(x: g.ox * 0.5, y: ry))
            // cols along the bottom gutter
            let cx = point(Double(i) + 0.5, 0, full).x
            ctx.draw(Text(cols[i]).font(.system(size: g.cell * 0.17, weight: .semibold))
                        .foregroundColor(Theme.inkLabel),
                     at: CGPoint(x: cx, y: g.oy + g.felt + (Double(full) - g.oy - g.felt) * 0.5))
        }
    }
}
