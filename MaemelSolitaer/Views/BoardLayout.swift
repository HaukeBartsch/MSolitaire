//
//  BoardLayout.swift
//  MaemelSolitaer
//
//  Computes where every pile and card sits for a given table size.
//

import CoreGraphics

struct BoardLayout {
    let size: CGSize
    let cardSize: CGSize
    let spacing: CGFloat
    let originX: CGFloat
    let topRowY: CGFloat
    let tableauY: CGFloat
    let wasteFan: CGFloat

    init(size: CGSize) {
        self.size = size
        let spacing = max(8, min(size.width * 0.014, 18))
        let widthLimited = (size.width - spacing * 6) / 7
        let heightLimited = size.height / 3.6 / 1.4
        let width = max(36, min(widthLimited, heightLimited))
        self.spacing = spacing
        cardSize = CGSize(width: width, height: width * 1.4)
        originX = (size.width - (width * 7 + spacing * 6)) / 2
        topRowY = 0
        tableauY = width * 1.4 + spacing * 1.6
        wasteFan = width * 0.3
    }

    func columnX(_ column: Int) -> CGFloat {
        originX + CGFloat(column) * (cardSize.width + spacing)
    }

    /// The frame of an empty pile.
    func slotFrame(for pile: PileID) -> CGRect {
        let origin: CGPoint
        switch pile {
        case .stock: origin = CGPoint(x: columnX(0), y: topRowY)
        case .waste: origin = CGPoint(x: columnX(1), y: topRowY)
        case .foundation(let i): origin = CGPoint(x: columnX(3 + i), y: topRowY)
        case .tableau(let i): origin = CGPoint(x: columnX(i), y: tableauY)
        }
        return CGRect(origin: origin, size: cardSize)
    }

    /// Vertical offset of each card in a column, compressed when the column gets long.
    func tableauOffsets(for column: [Card]) -> [CGFloat] {
        guard !column.isEmpty else { return [] }
        let h = cardSize.height
        var down = h * 0.14
        var up = h * 0.30
        let stacked = column.dropLast()
        let downSteps = CGFloat(stacked.filter { !$0.isFaceUp }.count)
        let upSteps = CGFloat(stacked.filter { $0.isFaceUp }.count)
        let budget = max(0, size.height - tableauY - h - 4)

        if down * downSteps + up * upSteps > budget {
            if downSteps > 0 {
                down = max(h * 0.05, min(down, (budget - up * upSteps) / downSteps))
            }
            if upSteps > 0 && down * downSteps + up * upSteps > budget {
                up = max(h * 0.1, (budget - down * downSteps) / upSteps)
            }
        }

        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for card in column {
            offsets.append(y)
            y += card.isFaceUp ? up : down
        }
        return offsets
    }

    func cardFrame(for pile: PileID, index: Int, in game: KlondikeGame) -> CGRect {
        let slot = slotFrame(for: pile)
        switch pile {
        case .waste:
            // In draw-3 mode the top three waste cards fan out to the right.
            let fanCount = min(game.drawCount == 3 ? 3 : 1, game.waste.count)
            let firstFanned = game.waste.count - fanCount
            let step = CGFloat(max(0, index - firstFanned))
            return slot.offsetBy(dx: step * wasteFan, dy: 0)
        case .tableau(let t):
            let offsets = tableauOffsets(for: game.cards(in: .tableau(t)))
            return slot.offsetBy(dx: 0, dy: offsets.indices.contains(index) ? offsets[index] : 0)
        case .stock, .foundation:
            return slot
        }
    }

    /// Generous area in which a dropped card snaps to a pile.
    func dropZone(for pile: PileID) -> CGRect {
        let slot = slotFrame(for: pile)
        switch pile {
        case .tableau:
            // The full column width (including the gaps) down to the bottom of the table.
            return CGRect(
                x: slot.minX - spacing / 2,
                y: slot.minY - spacing,
                width: slot.width + spacing,
                height: max(slot.height, size.height - slot.minY + spacing)
            )
        case .stock, .waste, .foundation:
            return slot.insetBy(dx: -spacing, dy: -spacing)
        }
    }

    /// Where a card would land on a pile — used for the magnetic fallback.
    func attachPoint(for pile: PileID, in game: KlondikeGame) -> CGPoint {
        let cards = game.cards(in: pile)
        let frame = cards.isEmpty ? slotFrame(for: pile) : cardFrame(for: pile, index: cards.count - 1, in: game)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}
