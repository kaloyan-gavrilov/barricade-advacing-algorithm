import SwiftUI
import QuoridorCore

// Disambiguate the board State from SwiftUI's @State property wrapper.
typealias BoardState = QuoridorCore.State

// "Maple · Sage felt" palette — a warm wooden games-table look.
// See design.md for the full spec. All UI colors flow from here.
enum Theme {
    // wood — window chrome, board frame, panel border
    static let woodDark  = Color(hex: 0xa6784a)
    static let woodMid   = Color(hex: 0xc99b67)
    static let woodLight = Color(hex: 0xcfa06d)
    static let woodEdge  = Color(hex: 0xb58f5f)   // raised-button bottom lip

    // walnut — the table surface the board sits on (darker than the maple frame)
    static let tableHi   = Color(hex: 0x6e4a2e)
    static let tableMid  = Color(hex: 0x5a3a22)
    static let tableLo   = Color(hex: 0x452c19)

    // felt — the playing surface
    static let feltLight = Color(hex: 0x9cb38f)
    static let feltDark  = Color(hex: 0x75906a)

    // paper / cream — panels, inset controls
    static let creamHi   = Color(hex: 0xfbf6ea)
    static let creamLo   = Color(hex: 0xefe3cd)
    static let panelHi   = Color(hex: 0xfbf6ea)
    static let panelLo   = Color(hex: 0xeee3cf)

    // ink — text over wood/cream
    static let ink       = Color(hex: 0x3a2c1c)   // primary
    static let inkDeep   = Color(hex: 0x4a2f18)   // over wood
    static let inkLabel  = Color(hex: 0x5a3d20)   // coord labels on frame
    static let subtle    = Color(hex: 0x7a6a52)   // muted captions

    // players (0 = You / blue, 1 = Opp / red)
    static let pFlat  = [Color(hex: 0x2f63c4), Color(hex: 0xc8341f)]
    static let pHi    = [Color(hex: 0x8fbcff), Color(hex: 0xff9a8a)]   // gloss highlight
    static let pMid   = [Color(hex: 0x2f6bd6), Color(hex: 0xe0402f)]
    static let pLo    = [Color(hex: 0x1c3f86), Color(hex: 0x8f1d15)]   // gloss core
    static let pWallHi = [Color(hex: 0x7aa5ec), Color(hex: 0xef8272)]
    static let pWallLo = [Color(hex: 0x2f63c4), Color(hex: 0xc8341f)]

    // accents
    static let accent    = Color(hex: 0xc56a3f)   // orange — Suggest / brand
    static let accentHi  = Color(hex: 0xe08a52)
    static let accentLo  = Color(hex: 0x9c4f2c)
    static let goodHi    = Color(hex: 0x6fce86)   // eval / suggestion green
    static let goodMid   = Color(hex: 0x3f9e5c)
    static let goodDark  = Color(hex: 0x2f7d47)
    static let bad       = Color(hex: 0xc8341f)

    static let emptyPip  = Color(hex: 0x000000).opacity(0.14)

    // Convenience gradients ------------------------------------------------
    static var wood: LinearGradient {
        LinearGradient(colors: [woodMid, woodDark],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var table: LinearGradient {
        LinearGradient(colors: [tableHi, tableMid, tableLo],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var frame: LinearGradient {
        LinearGradient(colors: [woodLight, woodDark],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var cream: LinearGradient {
        LinearGradient(colors: [creamHi, creamLo], startPoint: .top, endPoint: .bottom)
    }
    static var paper: LinearGradient {
        LinearGradient(colors: [panelHi, panelLo],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentFill: LinearGradient {
        LinearGradient(colors: [accentHi, accent], startPoint: .top, endPoint: .bottom)
    }
    static func pawnWall(_ i: Int) -> LinearGradient {
        LinearGradient(colors: [pWallHi[i], pWallLo[i]], startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue:  Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}

let WALL_THR = 0.33
let INSET = 0.06
