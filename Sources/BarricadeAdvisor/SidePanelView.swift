import SwiftUI
import QuoridorCore

struct SidePanelView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        let st = model.state
        VStack(alignment: .leading, spacing: 0) {
            header(st)
            divider()
            wallsSection(st)
            divider()
            evalSection(st)
            suggestionCard
            divider()
            legend()
            Spacer(minLength: 0)
            Text(model.status)
                .font(.system(size: 11)).foregroundColor(Theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 360)
        .background(
            Theme.paper
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.woodDark, lineWidth: 0))
        )
        .overlay(Rectangle().fill(Theme.woodDark).frame(width: 1), alignment: .leading)
    }

    // MARK: header
    private func header(_ st: BoardState) -> some View {
        VStack(spacing: 8) {
            (Text("Barricade ").foregroundColor(Theme.ink)
                + Text("Advisor").foregroundColor(Theme.accent))
                .font(.system(size: 23, weight: .bold, design: .serif))
            Text((model.mode == .vs ? "Vs Engine · \(LEVELS[model.level].name)" : "Analysis · both sides").uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(2.4)
                .foregroundColor(Theme.subtle)
            turnPill(st)
            if model.scoreYou + model.scoreOpp > 0 {
                Text("Score  you \(model.scoreYou) - \(model.scoreOpp) opp")
                    .font(.system(size: 10)).foregroundColor(Theme.subtle)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func turnPill(_ st: BoardState) -> some View {
        let color = model.mode == .analysis ? Theme.pFlat[st.turn]
            : (st.turn == model.human ? Theme.pFlat[0] : Theme.pFlat[1])
        return Text(turnText(st).uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(1.6)
            .foregroundColor(color)
            .padding(.horizontal, 18).padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func turnText(_ st: BoardState) -> String {
        if model.mode == .analysis {
            return st.turn == 0 ? "You (P0) to move" : "Opp (P1) to move"
        }
        if winner(st) != nil { return (winner(st) == model.human) ? "You win" : "Opp wins" }
        return st.turn == model.human ? "Your turn" : "Opponent's turn"
    }

    // MARK: walls
    private func wallsSection(_ st: BoardState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Walls in hand")
            wallReserve(0, "You", st)
            wallReserve(1, "Opp", st)
        }
    }

    private func wallReserve(_ idx: Int, _ label: String, _ st: BoardState) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.pFlat[idx]).frame(width: 10, height: 10)
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.ink)
                .frame(width: 34, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < st.wallsLeft[idx] ? AnyShapeStyle(Theme.pawnWall(idx)) : AnyShapeStyle(Theme.emptyPip))
                        .frame(width: 7, height: 19)
                }
            }
            Spacer(minLength: 0)
            Text("\(st.wallsLeft[idx])")
                .font(.system(size: 14, weight: .bold, design: .serif)).foregroundColor(Theme.ink)
        }
    }

    // MARK: evaluation
    private func evalSection(_ st: BoardState) -> some View {
        let v = max(-6.0, min(6.0, model.suggVal))
        let frac = (v + 6) / 12.0
        let favoured = model.suggVal >= 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Evaluation")
                Spacer()
                Text(abs(model.suggVal) > 0.05 ? String(format: "%+.2f", model.suggVal) : "even")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(favoured ? Theme.goodDark : Theme.bad)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: favoured ? [Theme.goodHi, Theme.goodMid] : [Theme.pHi[1], Theme.bad],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, g.size.width * frac))
                }
            }.frame(height: 12)
            Text(abs(model.suggVal) <= 0.05 ? "Even position"
                    : (favoured ? "\(sideName()) favoured" : "\(oppName()) favoured"))
                .font(.system(size: 12)).foregroundColor(Theme.subtle)
        }
    }

    private func sideName() -> String {
        model.mode == .analysis ? (model.state.turn == 0 ? "You" : "Opp")
            : (model.state.turn == model.human ? "You" : "Opp")
    }
    private func oppName() -> String { sideName() == "You" ? "Opp" : "You" }

    // MARK: suggestion card
    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✦ Suggested move".uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(1.6)
                .foregroundColor(Theme.accent)
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 7).fill(Theme.accentFill)
                    .frame(width: 30, height: 30)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 3, y: 2)
                Text(GameModel.notation(model.suggestion))
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.accent.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.accent.opacity(0.5), lineWidth: 1.5))
        .padding(.top, 16)
    }

    // MARK: legend
    private func legend() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Legend")
            legendRow(label: "You - race up") { Circle().fill(Theme.pFlat[0]).frame(width: 16, height: 16) }
            legendRow(label: "Opp - race down") { Circle().fill(Theme.pFlat[1]).frame(width: 16, height: 16) }
            legendRow(label: "Engine suggestion") {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Theme.goodHi, Theme.goodMid], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 24, height: 8)
            }
        }
    }

    private func legendRow<S: View>(label: String, @ViewBuilder swatch: () -> S) -> some View {
        HStack(spacing: 11) {
            swatch().frame(width: 24, alignment: .leading)
            Text(label).font(.system(size: 13)).foregroundColor(Theme.ink)
        }
    }

    // MARK: helpers
    private func sectionLabel(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 11, weight: .semibold)).tracking(1.6)
            .foregroundColor(Theme.subtle)
    }
    private func divider() -> some View {
        LinearGradient(colors: [.clear, Theme.woodDark.opacity(0.5), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .padding(.vertical, 18)
    }
}
