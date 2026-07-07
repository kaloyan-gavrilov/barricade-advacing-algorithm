// Renders the app icon PNG (1024x1024): a dark Quoridor board with two pawns
// and a gold barricade. Run: swift Tools/make_icon.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S: CGFloat = 1024

func col(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff)/255, green: CGFloat((hex >> 8) & 0xff)/255,
            blue: CGFloat(hex & 0xff)/255, alpha: 1)
}

let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// rounded background gradient
let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: S, height: S), xRadius: 180, yRadius: 180)
bgPath.addClip()
let grad = NSGradient(colors: [col(0x111a30), col(0x0a0e1a)])!
grad.draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: -90)

// 5x5 board inset
let n = 5
let margin: CGFloat = 150
let boardSize = S - 2 * margin
let cell = boardSize / CGFloat(n)
for r in 0..<n {
    for c in 0..<n {
        let x = margin + CGFloat(c) * cell
        let y = margin + CGFloat(r) * cell
        let inset: CGFloat = 10
        let tile = NSBezierPath(roundedRect: NSRect(x: x + inset, y: y + inset,
                                width: cell - 2*inset, height: cell - 2*inset),
                                xRadius: 16, yRadius: 16)
        (r == n-1 ? col(0x1b2f4d) : (r == 0 ? col(0x3a2030) : col(0x1e2942))).setFill()
        tile.fill()
        col(0x2b3960).setStroke(); tile.lineWidth = 3; tile.stroke()
    }
}

func pawn(_ r: Int, _ c: Int, _ fill: UInt32, _ glow: UInt32) {
    let cx = margin + (CGFloat(c) + 0.5) * cell
    let cy = margin + (CGFloat(r) + 0.5) * cell
    let rad = cell * 0.32
    col(glow).withAlphaComponent(0.25).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - rad*1.35, y: cy - rad*1.35, width: rad*2.7, height: rad*2.7)).fill()
    let disk = NSBezierPath(ovalIn: NSRect(x: cx - rad, y: cy - rad, width: rad*2, height: rad*2))
    col(fill).setFill(); disk.fill()
    NSColor.white.setStroke(); disk.lineWidth = 8; disk.stroke()
}
pawn(0, 2, 0xef4444, 0xfca5a5)   // red top-ish (row 0 bottom)
pawn(4, 2, 0x3b82f6, 0x93c5fd)   // blue

// a gold barricade between rows
ctx.setLineCap(.round)
col(0xd9a441).setStroke()
let wp = NSBezierPath()
let wy = margin + 3 * cell
wp.move(to: NSPoint(x: margin + 1.15 * cell, y: wy))
wp.line(to: NSPoint(x: margin + 3.85 * cell, y: wy))
wp.lineWidth = 34
wp.lineCapStyle = .round
wp.stroke()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
