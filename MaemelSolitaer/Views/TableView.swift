//
//  TableView.swift
//  MaemelSolitaer
//
//  The card table. All 52 cards live in one absolutely positioned layer, so every move —
//  tapped, dragged, undone or auto-completed — glides smoothly from pile to pile.
//

import SwiftUI

/// A card along with where and how it should be drawn.
private struct PlacedCard: Identifiable {
    let card: Card
    let pile: PileID
    let index: Int
    let frame: CGRect
    let zIndex: Double
    let isInteractive: Bool
    var id: Int { card.id }
}

private struct DragState {
    let pile: PileID
    let index: Int
    var translation: CGSize
}

struct TableView: View {
    @Environment(GameController.self) private var controller
    @State private var drag: DragState?
    /// Number of tableau cards dealt so far during the deal animation (`Int.max` when idle).
    @State private var dealtCount = Int.max

    private static let space = "table"

    var body: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(size: proxy.size)
            ZStack(alignment: .topLeading) {
                slots(layout: layout)
                ForEach(placedCards(layout: layout)) { item in
                    cardView(item, layout: layout)
                }
                hintGlow(layout: layout)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(.named(Self.space))
        }
        .task(id: controller.dealToken) {
            await runDealAnimation()
        }
    }

    // MARK: - Cards

    private func cardView(_ item: PlacedCard, layout: BoardLayout) -> some View {
        let dragged = isDragged(item)
        let offset = dragged ? (drag?.translation ?? .zero) : .zero
        return CardView(card: item.card, size: layout.cardSize, isHighlighted: isHinted(item))
            .modifier(ShakeEffect(animatableData: CGFloat(controller.shakes[item.card.id] ?? 0)))
            .scaleEffect(dragged ? 1.05 : 1)
            .shadow(color: .black.opacity(dragged ? 0.35 : 0), radius: dragged ? 12 : 0, y: dragged ? 8 : 0)
            .position(x: item.frame.midX + offset.width, y: item.frame.midY + offset.height)
            .zIndex(dragged ? 2000 + Double(item.index) : item.zIndex)
            .onTapGesture { handleTap(item) }
            .gesture(dragGesture(for: item, layout: layout))
            .allowsHitTesting(item.isInteractive && controller.canInteract && dealtCount == Int.max)
            .accessibilityLabel(item.card.isFaceUp ? item.card.spokenName : "Face-down card")
            .accessibilityAddTraits(item.isInteractive ? .isButton : [])
    }

    private func placedCards(layout: BoardLayout) -> [PlacedCard] {
        let game = controller.game
        let recent = controller.recentlyMoved
        let stockFrame = layout.slotFrame(for: .stock)
        var result: [PlacedCard] = []
        result.reserveCapacity(52)

        func boost(_ card: Card, _ z: Double) -> Double {
            recent.contains(card.id) ? z + 1000 : z
        }

        for (i, card) in game.stock.enumerated() {
            result.append(PlacedCard(card: card, pile: .stock, index: i, frame: stockFrame,
                                     zIndex: Double(i), isInteractive: i == game.stock.count - 1))
        }
        for (i, card) in game.waste.enumerated() {
            result.append(PlacedCard(card: card, pile: .waste, index: i,
                                     frame: layout.cardFrame(for: .waste, index: i, in: game),
                                     zIndex: boost(card, 100 + Double(i)), isInteractive: i == game.waste.count - 1))
        }
        for f in 0..<4 {
            let pile = game.foundations[f]
            for (i, card) in pile.enumerated() {
                result.append(PlacedCard(card: card, pile: .foundation(f), index: i,
                                         frame: layout.slotFrame(for: .foundation(f)),
                                         zIndex: boost(card, 200 + Double(i)), isInteractive: i == pile.count - 1))
            }
        }
        for t in 0..<7 {
            let column = game.tableau[t]
            let offsets = layout.tableauOffsets(for: column)
            let slot = layout.slotFrame(for: .tableau(t))
            for (i, card) in column.enumerated() {
                let order = dealOrder(column: t, row: i)
                if order >= dealtCount {
                    // Not dealt yet: wait face down on the deck.
                    var waiting = card
                    waiting.isFaceUp = false
                    result.append(PlacedCard(card: waiting, pile: .tableau(t), index: i, frame: stockFrame,
                                             zIndex: 80 - Double(order), isInteractive: false))
                } else {
                    result.append(PlacedCard(card: card, pile: .tableau(t), index: i,
                                             frame: slot.offsetBy(dx: 0, dy: offsets[i]),
                                             zIndex: boost(card, 300 + Double(i)), isInteractive: card.isFaceUp))
                }
            }
        }
        return result
    }

    /// Classic dealing order: one card to each column, row by row.
    private func dealOrder(column: Int, row: Int) -> Int {
        row * 7 - row * (row - 1) / 2 + (column - row)
    }

    private func isDragged(_ item: PlacedCard) -> Bool {
        guard let drag else { return false }
        return drag.pile == item.pile && item.index >= drag.index
    }

    private func isHinted(_ item: PlacedCard) -> Bool {
        guard let hint = controller.activeHint else { return false }
        if hint.to == nil {
            return item.pile == .stock && item.index == controller.game.stock.count - 1
        }
        return hint.from == item.pile && item.index >= hint.index
    }

    // MARK: - Interaction

    private func handleTap(_ item: PlacedCard) {
        switch item.pile {
        case .stock:
            controller.drawFromStock()
        case .foundation:
            break
        case .waste, .tableau:
            controller.tapCard(at: item.pile, index: item.index)
        }
    }

    private func dragGesture(for item: PlacedCard, layout: BoardLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { value in
                dragChanged(item, translation: value.translation)
            }
            .onEnded { value in
                dragEnded(item, translation: value.translation, layout: layout)
            }
    }

    private func dragChanged(_ item: PlacedCard, translation: CGSize) {
        guard controller.canInteract else { return }
        if let current = drag {
            guard current.pile == item.pile, current.index == item.index else { return }
            drag?.translation = translation
        } else {
            guard item.pile != .stock,
                  controller.game.movableCards(from: item.pile, at: item.index) != nil else { return }
            controller.clearHint()
            drag = DragState(pile: item.pile, index: item.index, translation: translation)
        }
    }

    private func dragEnded(_ item: PlacedCard, translation: CGSize, layout: BoardLayout) {
        guard let current = drag, current.pile == item.pile, current.index == item.index else { return }
        let distance = hypot(translation.width, translation.height)

        if let target = dropTarget(for: current, layout: layout) {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                drag = nil
                controller.performMove(from: current.pile, index: current.index, to: target)
            }
        } else if distance < layout.cardSize.width * 0.35 {
            // A tiny wobble of the finger counts as a tap.
            withAnimation(.spring(duration: 0.25)) { drag = nil }
            controller.tapCard(at: current.pile, index: current.index)
        } else {
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { drag = nil }
            controller.playRejectSound()
        }
    }

    /// Magnetic snapping: the valid pile with the most overlap wins; failing that,
    /// the nearest valid pile within reach.
    private func dropTarget(for drag: DragState, layout: BoardLayout) -> PileID? {
        let game = controller.game
        guard let moving = game.movableCards(from: drag.pile, at: drag.index) else { return nil }

        let origin = layout.cardFrame(for: drag.pile, index: drag.index, in: game)
        let dragged = origin.offsetBy(dx: drag.translation.width, dy: drag.translation.height)
        let reach = dragged.insetBy(dx: -layout.cardSize.width * 0.15, dy: -layout.cardSize.height * 0.15)
        let center = CGPoint(x: dragged.midX, y: dragged.midY)

        var candidates: [PileID] = (0..<7).map { .tableau($0) }
        if moving.count == 1 { candidates += (0..<4).map { .foundation($0) } }
        let valid = candidates.filter { $0 != drag.pile && game.canPlace(moving, on: $0) }

        var best: (pile: PileID, area: CGFloat)?
        for pile in valid {
            let overlap = layout.dropZone(for: pile).intersection(reach)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > (best?.area ?? 0) { best = (pile, area) }
        }
        if let best { return best.pile }

        var nearest: (pile: PileID, distance: CGFloat)?
        for pile in valid {
            let point = layout.attachPoint(for: pile, in: game)
            let distance = hypot(point.x - center.x, point.y - center.y)
            if distance < (nearest?.distance ?? layout.cardSize.width * 1.6) {
                nearest = (pile, distance)
            }
        }
        return nearest?.pile
    }

    // MARK: - Empty piles and hints

    @ViewBuilder
    private func slots(layout: BoardLayout) -> some View {
        let game = controller.game
        let stockFrame = layout.slotFrame(for: .stock)
        SlotView(kind: .stock(canRecycle: game.stock.isEmpty && !game.waste.isEmpty), size: layout.cardSize)
            .position(x: stockFrame.midX, y: stockFrame.midY)
            .onTapGesture { controller.drawFromStock() }
            .accessibilityLabel("Deck")
            .accessibilityAddTraits(.isButton)

        ForEach(0..<4, id: \.self) { f in
            let frame = layout.slotFrame(for: .foundation(f))
            SlotView(kind: .foundation(Suit(rawValue: f) ?? .spades), size: layout.cardSize)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }
        ForEach(0..<7, id: \.self) { t in
            let frame = layout.slotFrame(for: .tableau(t))
            SlotView(kind: .tableau, size: layout.cardSize)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func hintGlow(layout: BoardLayout) -> some View {
        if let hint = controller.activeHint {
            let frame = hintTargetFrame(hint, layout: layout)
            HintGlow(size: frame.size, cornerRadius: layout.cardSize.width * 0.09)
                .position(x: frame.midX, y: frame.midY)
                .zIndex(3000)
                .allowsHitTesting(false)
        }
    }

    private func hintTargetFrame(_ hint: GameHint, layout: BoardLayout) -> CGRect {
        guard let destination = hint.to else { return layout.slotFrame(for: .stock) }
        let cards = controller.game.cards(in: destination)
        if cards.isEmpty { return layout.slotFrame(for: destination) }
        return layout.cardFrame(for: destination, index: cards.count - 1, in: controller.game)
    }

    // MARK: - Deal animation

    private func runDealAnimation() async {
        guard controller.pendingDealAnimation else { return }
        controller.pendingDealAnimation = false
        dealtCount = 0
        try? await Task.sleep(for: .milliseconds(350))
        for count in 1...28 {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { dealtCount = count }
            if count % 4 == 0 { controller.playTick() }
            try? await Task.sleep(for: .milliseconds(45))
        }
        dealtCount = Int.max
    }
}

/// Outline of an empty pile.
struct SlotView: View {
    enum Kind {
        case stock(canRecycle: Bool)
        case foundation(Suit)
        case tableau
    }

    let kind: Kind
    let size: CGSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.width * 0.09, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.14))
            shape.strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            content
        }
        .frame(width: size.width, height: size.height)
        .contentShape(shape)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .stock(let canRecycle):
            if canRecycle {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: size.width * 0.38, weight: .bold))
                    Text("Tap")
                        .font(.system(size: size.width * 0.16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
        case .foundation(let suit):
            Image(systemName: suit.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 0.45)
                .foregroundStyle(.white.opacity(0.3))
        case .tableau:
            Text("K")
                .font(.system(size: size.width * 0.4, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.22))
        }
    }
}

/// A softly pulsing golden outline showing where a hinted card should go.
struct HintGlow: View {
    let size: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Theme.gold, lineWidth: 6)
            .shadow(color: Theme.gold, radius: 10)
            .frame(width: size.width + 8, height: size.height + 8)
            .phaseAnimator([0.35, 1.0]) { content, phase in
                content.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.6)
            }
    }
}
