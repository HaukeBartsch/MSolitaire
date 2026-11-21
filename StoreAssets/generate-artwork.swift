import AppKit

// MARK: - Palette & helpers

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

struct Palette {
    var bgTop = rgb(0.13, 0.38, 0.25)
    var bgBottom = rgb(0.07, 0.25, 0.16)
    var face = rgb(1.0, 0.99, 0.96)
    var red = rgb(0.80, 0.04, 0.10)
    var black = rgb(0.07, 0.07, 0.09)
    var gold = rgb(0.99, 0.80, 0.32)
    var glow = true
}
let light = Palette()
let dark = Palette(bgTop: rgb(0.06, 0.16, 0.11), bgBottom: rgb(0.02, 0.07, 0.05))
let tinted = Palette(bgTop: .black, bgBottom: .black,
                     face: rgb(0.92, 0.92, 0.92), red: rgb(0.25, 0.25, 0.25), black: rgb(0.05, 0.05, 0.05),
                     gold: rgb(0.85, 0.85, 0.85), glow: false)

var cg: CGContext { NSGraphicsContext.current!.cgContext }

func render(width: Int, height: Int, path: String, _ body: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    let base = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    base.cgContext.translateBy(x: 0, y: CGFloat(height))
    base.cgContext.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: base.cgContext, flipped: true)
    body()
    NSGraphicsContext.restoreGraphicsState()
    // Re-save without an alpha channel (required for the app icon, harmless for store art).
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let flat = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, flat.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest))
    print("wrote \(path) \(width)x\(height)")
}

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
    return base
}
func serif(_ size: CGFloat) -> NSFont { NSFont(name: "Georgia-Bold", size: size) ?? .boldSystemFont(ofSize: size) }

func textSize(_ s: String, _ font: NSFont, maxWidth: CGFloat = 10_000) -> CGSize {
    let r = (s as NSString).boundingRect(with: NSSize(width: maxWidth, height: 10_000),
                                         options: [.usesLineFragmentOrigin], attributes: [.font: font])
    return CGSize(width: ceil(r.width), height: ceil(r.height))
}
@discardableResult
func text(_ s: String, _ font: NSFont, _ color: NSColor, at origin: CGPoint, maxWidth: CGFloat = 10_000,
          align: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> CGSize {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    p.lineSpacing = lineSpacing
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: p]
    let size = textSize(s, font, maxWidth: maxWidth)
    NSAttributedString(string: s, attributes: attrs).draw(
        with: CGRect(origin: origin, size: CGSize(width: maxWidth == 10_000 ? size.width + 4 : maxWidth, height: size.height + 4)),
        options: [.usesLineFragmentOrigin])
    return size
}

func symbol(_ name: String, in rect: CGRect, color: NSColor, secondary: NSColor? = nil, weight: NSFont.Weight = .bold) {
    let cfg = NSImage.SymbolConfiguration(pointSize: 400, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: secondary.map { [color, $0] } ?? [color]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else {
        print("missing symbol \(name)"); return
    }
    let s = img.size
    let k = min(rect.width / s.width, rect.height / s.height)
    let r = CGRect(x: rect.midX - s.width * k / 2, y: rect.midY - s.height * k / 2, width: s.width * k, height: s.height * k)
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

func shadowed(color: NSColor, blur: CGFloat, dy: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowColor = color
    sh.shadowBlurRadius = blur
    sh.shadowOffset = NSSize(width: 0, height: dy)
    sh.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func rotated(about c: CGPoint, degrees: CGFloat, _ body: () -> Void) {
    cg.saveGState()
    cg.translateBy(x: c.x, y: c.y)
    cg.rotate(by: degrees * .pi / 180)
    body()
    cg.restoreGState()
}

func background(_ w: Int, _ h: Int, _ p: Palette, vignette: CGFloat = 0.28) {
    let rect = CGRect(x: 0, y: 0, width: w, height: h)
    NSGradient(starting: p.bgTop, ending: p.bgBottom)!.draw(in: rect, angle: 90)
    if p.glow {
        NSGradient(colors: [.clear, NSColor.black.withAlphaComponent(vignette)])!
            .draw(fromCenter: CGPoint(x: w / 2, y: h / 2), radius: CGFloat(h) * 0.35,
                  toCenter: CGPoint(x: w / 2, y: h / 2), radius: CGFloat(max(w, h)) * 0.75, options: [.drawsAfterEndingLocation])
    }
}

// MARK: - Cards

enum Suit: String { case spades = "suit.spade.fill", hearts = "suit.heart.fill", diamonds = "suit.diamond.fill", clubs = "suit.club.fill"
    var isRed: Bool { self == .hearts || self == .diamonds } }

/// Draws a face-up card centred on the current origin (rotate/translate first).
func card(w: CGFloat, rank: String, suit: Suit, _ p: Palette) {
    let h = w * 1.4
    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    let shape = NSBezierPath(roundedRect: rect, xRadius: w * 0.09, yRadius: w * 0.09)
    shadowed(color: NSColor.black.withAlphaComponent(0.45), blur: w * 0.09, dy: -w * 0.04) {
        p.face.setFill(); shape.fill()
    }
    NSColor.black.withAlphaComponent(0.28).setStroke()
    shape.lineWidth = max(1, w * 0.012); shape.stroke()

    let ink = suit.isRed ? p.red : p.black
    text(rank, roundedFont(h * 0.22, .heavy), ink, at: CGPoint(x: rect.minX + w * 0.07, y: rect.minY + h * 0.0))
    symbol(suit.rawValue, in: CGRect(x: rect.maxX - w * 0.07 - h * 0.17, y: rect.minY + h * 0.045, width: h * 0.17, height: h * 0.17), color: ink)

    let art = CGRect(x: rect.minX, y: rect.minY + h * 0.31, width: w, height: h * 0.66)
    if ["J", "Q", "K"].contains(rank) {
        let box = CGRect(x: art.minX + w * 0.14, y: art.minY, width: w * 0.72, height: art.height - w * 0.12)
        let bp = NSBezierPath(roundedRect: box, xRadius: w * 0.06, yRadius: w * 0.06)
        ink.withAlphaComponent(0.08).setFill(); bp.fill()
        ink.withAlphaComponent(0.35).setStroke(); bp.lineWidth = max(1, w * 0.015); bp.stroke()
        symbol("crown.fill", in: CGRect(x: box.midX - w * 0.1, y: box.minY + w * 0.05, width: w * 0.2, height: w * 0.16),
               color: ink.withAlphaComponent(rank == "K" ? 1 : 0.45))
        let f = serif(w * 0.42)
        let sz = textSize(rank, f)
        text(rank, f, ink, at: CGPoint(x: box.midX - sz.width / 2, y: box.midY - sz.height * 0.38))
    } else {
        let k = rank == "A" ? 0.62 : 0.52
        symbol(suit.rawValue, in: CGRect(x: art.midX - w * k / 2, y: art.midY - w * k / 2 - w * 0.04, width: w * k, height: w * k), color: ink)
    }
}

func charmMedallion(_ name: String, tint: NSColor, in rect: CGRect) {
    let c = NSBezierPath(ovalIn: rect)
    tint.withAlphaComponent(0.22).setFill(); c.fill()
    tint.setStroke(); c.lineWidth = max(2, rect.width * 0.04); c.stroke()
    symbol(name, in: rect.insetBy(dx: rect.width * 0.26, dy: rect.height * 0.26), color: tint)
}

func capsule(_ rect: CGRect, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 3) {
    let p = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    fill.setFill(); p.fill()
    if let stroke { stroke.setStroke(); p.lineWidth = lineWidth; p.stroke() }
}

let gold = rgb(0.99, 0.80, 0.32)
struct Charm { let name: String; let symbol: String; let tint: NSColor; let detail: String }
let royal = Charm(name: "Royal Court", symbol: "crown.fill", tint: gold, detail: "Kings give +50 points when moved to the foundation.")
let friend = Charm(name: "Foundation Friend", symbol: "square.stack.3d.up.fill", tint: rgb(0.55, 0.85, 1.0), detail: "+10 points for every card moved to the foundation.")
let second = Charm(name: "Second Chance", symbol: "arrow.uturn.backward", tint: rgb(0.86, 0.72, 1.0), detail: "Undo moves are always free.")
let eyes = Charm(name: "Bright Eyes", symbol: "eye.fill", tint: rgb(0.6, 0.95, 0.65), detail: "")
let hearts = Charm(name: "Heart of Gold", symbol: "suit.heart.fill", tint: rgb(1.0, 0.52, 0.52), detail: "")
let tidy = Charm(name: "Tidy Table", symbol: "sparkles", tint: rgb(0.6, 0.95, 0.65), detail: "")
let ace = Charm(name: "Ace Starter", symbol: "a.circle.fill", tint: rgb(0.55, 0.85, 1.0), detail: "")
let owl = Charm(name: "Wise Owl", symbol: "lightbulb.fill", tint: rgb(0.86, 0.72, 1.0), detail: "")
let clover = Charm(name: "Lucky Clover", symbol: "suit.club.fill", tint: rgb(0.78, 0.86, 1.0), detail: "")

// MARK: - App icon

func icon(_ p: Palette, path: String) {
    let S = 1024
    render(width: S, height: S, path: path) {
        background(S, S, p, vignette: 0.35)
        if p.glow {
            NSGradient(colors: [gold.withAlphaComponent(0.30), .clear])!
                .draw(fromCenter: CGPoint(x: 512, y: 520), radius: 0, toCenter: CGPoint(x: 512, y: 520), radius: 520, options: [])
        }
        rotated(about: CGPoint(x: 345, y: 520), degrees: -16) { card(w: 390, rank: "K", suit: .spades, p) }
        rotated(about: CGPoint(x: 640, y: 530), degrees: 8) { card(w: 390, rank: "A", suit: .hearts, p) }
    }
}

// MARK: - Store art

func hero(_ w: Int, _ h: Int, path: String) {
    let W = CGFloat(w), H = CGFloat(h), s = H / 1000
    let p = light
    render(width: w, height: h, path: path) {
        background(w, h, p)
        let x0 = W * 0.07
        // Title, shrunk until it fits its column.
        var size = 190 * s
        while textSize("Solitaire", serif(size)).width > W * 0.40 { size -= 4 }
        let title = serif(size)
        shadowed(color: NSColor.black.withAlphaComponent(0.4), blur: 12 * s, dy: -4 * s) {
            text("Mämel", title, .white, at: CGPoint(x: x0, y: H * 0.13))
            text("Solitaire", title, gold, at: CGPoint(x: x0, y: H * 0.13 + size * 1.08))
        }
        let ty = H * 0.13 + size * 2.3
        text("A relaxing journey through", roundedFont(44 * s, .semibold), NSColor.white.withAlphaComponent(0.92), at: CGPoint(x: x0, y: ty))
        text("classic Klondike", roundedFont(44 * s, .semibold), NSColor.white.withAlphaComponent(0.92), at: CGPoint(x: x0, y: ty + 56 * s))
        var by = ty + 44 * s * 3.6
        for line in ["Big, clear cards", "No timers, no pressure", "Every deal can be won"] {
            symbol("checkmark.circle.fill", in: CGRect(x: x0, y: by, width: 46 * s, height: 46 * s), color: rgb(0.07, 0.25, 0.16), secondary: gold)
            text(line, roundedFont(40 * s, .semibold), .white, at: CGPoint(x: x0 + 66 * s, y: by + 2 * s))
            by += 72 * s
        }
        // Card fan.
        let cardW = 0.40 * H
        let cx = W - W * 0.05 - 0.40 * H
        let pivot = CGPoint(x: cx, y: H * 0.57 + 0.40 * H)
        let fan: [(String, Suit)] = [("10", .clubs), ("J", .diamonds), ("Q", .spades), ("K", .hearts), ("A", .spades)]
        for (i, c) in fan.enumerated() {
            let angle = CGFloat(i - 2) * 11
            let r = 0.42 * H
            let center = CGPoint(x: pivot.x + r * sin(angle * .pi / 180), y: pivot.y - r * cos(angle * .pi / 180))
            rotated(about: center, degrees: angle) { card(w: cardW, rank: c.0, suit: c.1, p) }
        }
        // Score pop with charm chips above the fan.
        let px = cx, py = H * 0.03
        let popFont = roundedFont(110 * s, .black)
        let ps = textSize("+70", popFont)
        let pr = CGRect(x: px - ps.width / 2 - 36 * s, y: py, width: ps.width + 72 * s, height: ps.height + 16 * s)
        capsule(pr, fill: NSColor.black.withAlphaComponent(0.65), stroke: gold.withAlphaComponent(0.8), lineWidth: 4 * s)
        text("+70", popFont, gold, at: CGPoint(x: pr.minX + 36 * s, y: pr.minY + 6 * s))
        let chipFont = roundedFont(56 * s, .heavy)
        let chipWidths = ["+50", "+10"].map { textSize($0, chipFont).width + 100 * s }
        var chipX = px - (chipWidths.reduce(0, +) + 20 * s) / 2
        for (c, amount) in [(royal, "+50"), (friend, "+10")] {
            let cf = roundedFont(56 * s, .heavy)
            let cs = textSize(amount, cf)
            let rect = CGRect(x: chipX, y: pr.maxY + 18 * s, width: cs.width + 100 * s, height: 78 * s)
            capsule(rect, fill: NSColor.black.withAlphaComponent(0.72), stroke: c.tint, lineWidth: 3 * s)
            charmMedallion(c.symbol, tint: c.tint, in: CGRect(x: rect.minX + 7 * s, y: rect.minY + 7 * s, width: 64 * s, height: 64 * s))
            text(amount, cf, c.tint, at: CGPoint(x: rect.minX + 82 * s, y: rect.minY + 8 * s))
            chipX += rect.width + 20 * s
        }
    }
}

func charmsScene(_ w: Int, _ h: Int, path: String) {
    let W = CGFloat(w), H = CGFloat(h), s = H / 1000
    let p = light
    render(width: w, height: h, path: path) {
        background(w, h, p)
        let x0 = W * 0.07, colW = W * 0.38
        var size = 120 * s
        while textSize("Choose a charm", serif(size)).width > colW { size -= 4 }
        text("Choose a charm", serif(size), .white, at: CGPoint(x: x0, y: H * 0.10))
        text("Pick one after every round — up to nine.", roundedFont(40 * s, .semibold), NSColor.white.withAlphaComponent(0.9),
             at: CGPoint(x: x0, y: H * 0.10 + size * 1.25), maxWidth: colW)
        var y = H * 0.36
        for (i, c) in [royal, friend, second].enumerated() {
            let rect = CGRect(x: x0, y: y, width: colW, height: 0.17 * H)
            let bp = NSBezierPath(roundedRect: rect, xRadius: 28 * s, yRadius: 28 * s)
            (i == 0 ? c.tint.withAlphaComponent(0.22) : NSColor.black.withAlphaComponent(0.32)).setFill(); bp.fill()
            (i == 0 ? gold : NSColor.white.withAlphaComponent(0.25)).setStroke(); bp.lineWidth = (i == 0 ? 6 : 2) * s; bp.stroke()
            charmMedallion(c.symbol, tint: c.tint, in: CGRect(x: rect.minX + 28 * s, y: rect.midY - 56 * s, width: 112 * s, height: 112 * s))
            text(c.name, roundedFont(46 * s, .bold), .white, at: CGPoint(x: rect.minX + 170 * s, y: rect.minY + 24 * s))
            text(c.detail, roundedFont(32 * s, .regular), NSColor.white.withAlphaComponent(0.88),
                 at: CGPoint(x: rect.minX + 170 * s, y: rect.minY + 82 * s), maxWidth: colW - 200 * s)
            y += rect.height + 26 * s
        }
        // 3 x 3 charm panel.
        let tile = 0.215 * H, gap = 0.03 * H
        let panelW = 3 * tile + 4 * gap, panelH = 3 * tile + 4 * gap + 0.09 * H
        let panel = CGRect(x: W - W * 0.06 - panelW, y: (H - panelH) / 2, width: panelW, height: panelH)
        let pp = NSBezierPath(roundedRect: panel, xRadius: 36 * s, yRadius: 36 * s)
        NSColor.black.withAlphaComponent(0.32).setFill(); pp.fill()
        NSColor.white.withAlphaComponent(0.16).setStroke(); pp.lineWidth = 3 * s; pp.stroke()
        text("Your Charms  6 of 9", roundedFont(46 * s, .bold), NSColor.white.withAlphaComponent(0.92),
             at: CGPoint(x: panel.minX + gap, y: panel.minY + 28 * s))
        let owned = [royal, friend, hearts, second, tidy, owl]
        for i in 0..<9 {
            let r = CGRect(x: panel.minX + gap + CGFloat(i % 3) * (tile + gap),
                           y: panel.minY + 0.09 * H + gap + CGFloat(i / 3) * (tile + gap), width: tile, height: tile)
            let tp = NSBezierPath(roundedRect: r, xRadius: 24 * s, yRadius: 24 * s)
            if i < owned.count {
                NSColor.black.withAlphaComponent(0.32).setFill(); tp.fill()
                NSColor.white.withAlphaComponent(0.25).setStroke(); tp.lineWidth = 2 * s; tp.stroke()
                charmMedallion(owned[i].symbol, tint: owned[i].tint, in: CGRect(x: r.midX - 56 * s, y: r.minY + 20 * s, width: 112 * s, height: 112 * s))
                text(owned[i].name, roundedFont(28 * s, .bold), .white,
                     at: CGPoint(x: r.minX, y: r.maxY - 52 * s), maxWidth: r.width, align: .center)
            } else {
                NSColor.black.withAlphaComponent(0.15).setFill(); tp.fill()
                NSColor.white.withAlphaComponent(0.25).setStroke(); tp.lineWidth = 2 * s
                tp.setLineDash([14 * s, 10 * s], count: 2, phase: 0); tp.stroke()
                text("Empty", roundedFont(30 * s, .regular), NSColor.white.withAlphaComponent(0.5),
                     at: CGPoint(x: r.minX, y: r.midY - 20 * s), maxWidth: r.width, align: .center)
            }
        }
    }
}

// MARK: - Run

let out = CommandLine.arguments[1]
icon(light, path: "\(out)/icon.png")
icon(dark, path: "\(out)/icon-dark.png")
icon(tinted, path: "\(out)/icon-tinted.png")
for (w, h) in [(5244, 2950), (3840, 1646)] {
    hero(w, h, path: "\(out)/store-hero-\(w)x\(h).png")
    charmsScene(w, h, path: "\(out)/store-charms-\(w)x\(h).png")
}
