import SwiftUI
import QuoridorCore

struct ContentView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .zIndex(10)   // keep dropdown drawers above the board row
            HStack(spacing: 0) {
                boardColumn
                SidePanelView(model: model)
            }
            // toolbar/board divider lives here (below the toolbar in z-order) so
            // an open dropdown drawer paints over it instead of under it
            .overlay(Rectangle().fill(Color.black.opacity(0.30)).frame(height: 1), alignment: .top)
            statusBar
        }
        .frame(minWidth: 1040, minHeight: 720)
    }

    // MARK: - board column with goal captions
    private var boardColumn: some View {
        VStack(spacing: 14) {
            goalCaption(top: true)
            BoardView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            goalCaption(top: false)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.table.overlay(TableGrain()))
    }

    // Top of the board is player 0's goal; caption follows who the human plays.
    // Deliberately understated so it reads as a hint, not a headline.
    private func goalCaption(top: Bool) -> some View {
        let isHumanGoal = (top ? 0 : 1) == model.human
        let color = top ? Theme.pFlat[0] : Theme.pFlat[1]
        let who = isHumanGoal ? "You finish here" : "Opp finishes here"
        return Text(who)
            .font(.system(size: 11, weight: .medium))
            .tracking(0.6)
            .foregroundColor(color.opacity(0.62))
    }

    // MARK: - toolbar
    private var toolbar: some View {
        HStack(spacing: 12) {
            DropField(width: 168, current: model.mode.label,
                      options: GameMode.allCases.map { ($0.label, $0) }) {
                model.mode = $0; model.settingsChanged()
            }
            DropField(width: 128, current: LEVELS[model.level].name,
                      options: LEVELS.indices.map { (LEVELS[$0].name, $0) }) {
                model.level = $0; model.settingsChanged()
            }
            DropField(width: 150, current: model.human == 0 ? "You play Blue" : "You play Red",
                      options: [("You play Blue", 0), ("You play Red", 1)]) {
                if $0 != model.human { model.human = $0; model.reset() }
            }

            Text("HINTS")
                .font(.system(size: 11, weight: .semibold)).tracking(1.6)
                .foregroundColor(Theme.creamHi).fixedSize()
                .padding(.leading, 6)
            Toggle("", isOn: Binding(get: { model.showHints }, set: { _ in model.toggleHints() }))
                .toggleStyle(.switch).tint(Theme.goodMid).labelsHidden()

            Spacer(minLength: 12)

            StatsButton(model: model)
            Button("New Game") { model.rematch() }.buttonStyle(WoodButton())
            Button("Reset") { model.reset() }.buttonStyle(WoodButton())
            Button("Undo") { model.undo() }.buttonStyle(WoodButton())
            Button("✦ Suggest") { model.resuggest() }.buttonStyle(WoodButton(accent: true))
        }
        .labelsHidden()
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Theme.table.overlay(TableGrain()))
    }

    // MARK: - status bar
    private var statusBar: some View {
        Text(model.status)
            .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.creamHi.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Theme.table.overlay(TableGrain()))
            .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }
}

// MARK: - walnut table grain (vertical fibers + faint plank seams)
struct TableGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var x = 0.0
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(.black.opacity(0.05)), lineWidth: 1)
                x += 4
            }
            // wider plank seams
            var seam = 90.0
            while seam < size.width {
                var p = Path()
                p.move(to: CGPoint(x: seam, y: 0)); p.addLine(to: CGPoint(x: seam, y: size.height))
                ctx.stroke(p, with: .color(.black.opacity(0.14)), lineWidth: 1.5)
                seam += 128
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - custom dropdown — a wooden drawer that slides out flush under the pill
struct DropField<T: Hashable>: View {
    let width: CGFloat
    let current: String
    let options: [(String, T)]
    let onPick: (T) -> Void
    @SwiftUI.State private var open = false
    @SwiftUI.State private var hovered = -1

    private let pillH: CGFloat = 34

    // pill: square its bottom corners while open so the drawer joins seamlessly
    private var pillShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 9, bottomLeadingRadius: open ? 0 : 9,
            bottomTrailingRadius: open ? 0 : 9, topTrailingRadius: 9)
    }

    var body: some View {
        Button { open.toggle(); hovered = -1 } label: {
            HStack(spacing: 8) {
                Text(current).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(Theme.woodDark)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .animation(.easeOut(duration: 0.15), value: open)
            }
            .padding(.horizontal, 12).frame(width: width, height: pillH)
            .background(pillShape.fill(Theme.cream))
            .overlay(pillShape.stroke(Theme.woodDark.opacity(0.45), lineWidth: 1))
            .background(pillShape.fill(Color.black.opacity(0.25)).offset(y: open ? 0 : 1.5))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if open {
                ZStack(alignment: .topLeading) {
                    // full-window catcher: a click anywhere else closes the drawer
                    Rectangle().fill(Color.black.opacity(0.001))
                        .frame(width: 4000, height: 3000).offset(x: -2000, y: -1500)
                        .onTapGesture { open = false }
                    drawer.offset(y: pillH)
                }
            }
        }
        .zIndex(open ? 100 : 0)
    }

    // the drawer: square top (continuous with the pill), rounded bottom
    private var drawer: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 9,
            bottomTrailingRadius: 9, topTrailingRadius: 0)
        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                let selected = opt.0 == current
                if idx > 0 {
                    Rectangle().fill(Theme.woodDark.opacity(0.12)).frame(height: 1)
                }
                Button { onPick(opt.1); open = false } label: {
                    HStack(spacing: 8) {
                        Text(opt.0)
                            .font(.system(size: 13, weight: selected ? .bold : .medium))
                            .foregroundColor(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 12)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(width: width, alignment: .leading)
                    .background(hovered == idx ? Theme.accent.opacity(0.14)
                                : (selected ? Theme.accent.opacity(0.06) : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? idx : (hovered == idx ? -1 : hovered) }
            }
        }
        .frame(width: width)
        .background(shape.fill(Theme.cream))
        .clipShape(shape)
        .overlay(shape.stroke(Theme.woodDark.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 8, y: 5)
    }
}

// MARK: - stats popover button
struct StatsButton: View {
    @ObservedObject var model: GameModel
    @SwiftUI.State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: "chart.bar.fill")
        }
        .buttonStyle(WoodButton())
        .help("Game stats")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            let st = model.state
            VStack(alignment: .leading, spacing: 10) {
                Text("GAME STATS").font(.system(size: 11, weight: .bold)).tracking(1.6)
                    .foregroundColor(Theme.subtle)
                statRow("Moves played", "\(model.history.count - 1)")
                statRow("Score (you-opp)", "\(model.scoreYou)-\(model.scoreOpp)")
                statRow("Your walls used", "\(10 - st.wallsLeft[0])")
                statRow("Opp walls used", "\(10 - st.wallsLeft[1])")
                statRow("Evaluation",
                        abs(model.suggVal) <= 0.05 ? "even" : String(format: "%+.2f", model.suggVal))
                statRow("Difficulty", LEVELS[model.level].name)
            }
            .padding(16)
            .frame(width: 240)
            .background(Theme.cream)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(Theme.subtle)
            Spacer(minLength: 12)
            Text(value).font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundColor(Theme.ink)
        }
    }
}

// MARK: - button styles

// Raised cream key with a wooden bottom lip; orange when `accent`.
struct WoodButton: ButtonStyle {
    var accent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .bold)).tracking(0.4)
            .lineLimit(1).fixedSize()
            .foregroundColor(accent ? .white : Theme.inkDeep)
            .padding(.horizontal, 15).frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(accent ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(Theme.cream))
            )
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.5), lineWidth: 1)
                .blendMode(.overlay))
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(accent ? Theme.accentLo : Color.black.opacity(0.3))
                    .offset(y: 2)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
