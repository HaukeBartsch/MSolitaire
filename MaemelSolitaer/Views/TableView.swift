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
            let layout = BoardLayout(size: proxy.size,
                                     columns: controller.game.tableau.count,
                                     foundations: controller.game.foundations.count)
            let placed = placedCards(layout: layout)
            ZStack(alignment: .topLeading) {
                slots(layout: layout)
                ForEach(placed) { item in
                    cardView(item, layout: layout)
                }
                hintGlow(layout: layout)
                scorePops(placed: placed, layout: layout)
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
            #if !os(tvOS)
            .gesture(dragGesture(for: item, layout: layout))
            #endif
            .allowsHitTesting(item.isInteractive && controller.canInteract && dealtCount == Int.max)
            .accessibilityLabel(accessibilityLabel(for: item))
            .accessibilityAddTraits(.isButton)
            // Only cards the player can act on are announced (no hidden or buried cards).
            .accessibilityHidden(!item.isInteractive || dealtCount != Int.max)
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
        for f in game.foundations.indices {
            let pile = game.foundations[f]
            for (i, card) in pile.enumerated() {
                result.append(PlacedCard(card: card, pile: .foundation(f), index: i,
                                         frame: layout.slotFrame(for: .foundation(f)),
                                         zIndex: boost(card, 200 + Double(i)), isInteractive: i == pile.count - 1))
            }
        }
        let columnCount = game.tableau.count
        for t in game.tableau.indices {
            let column = game.tableau[t]
            let offsets = layout.tableauOffsets(for: column)
            let slot = layout.slotFrame(for: .tableau(t))
            for (i, card) in column.enumerated() {
                let order = dealOrder(column: t, row: i, columns: columnCount)
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
    private func dealOrder(column: Int, row: Int, columns: Int) -> Int {
        row * columns - row * (row - 1) / 2 + (column - row)
    }

    private func accessibilityLabel(for item: PlacedCard) -> String {
        switch item.pile {
        case .stock:
            return String(localized: "Deck, \(controller.game.stock.count) cards left",
                          comment: "VoiceOver label for the face-down deck")
        case .foundation:
            return String(localized: "\(item.card.spokenName), foundation pile",
                          comment: "VoiceOver label for the top card of a foundation pile")
        case .waste, .tableau:
            return item.card.spokenName
        }
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

    #if !os(tvOS)
    private func dragGesture(for item: PlacedCard, layout: BoardLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { value in
                dragChanged(item, translation: value.translation)
            }
            .onEnded { value in
                dragEnded(item, translation: value.translation, layout: layout)
            }
    }
    #endif

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

        var candidates: [PileID] = game.tableau.indices.map { .tableau($0) }
        if moving.count == 1 { candidates += game.foundations.indices.map { .foundation($0) } }
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
            .accessibilityLabel(game.waste.isEmpty ? String(localized: "Empty deck")
                                : String(localized: "Empty deck, tap to turn the cards over again"))
            .accessibilityAddTraits(.isButton)
            .accessibilityHidden(!game.stock.isEmpty)

        ForEach(game.foundations.indices, id: \.self) { f in
            let frame = layout.slotFrame(for: .foundation(f))
            let suit = Suit(rawValue: f % 4) ?? .spades
            SlotView(kind: .foundation(suit), size: layout.cardSize)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .accessibilityLabel(String(localized: "Empty \(suit.name) foundation pile",
                                           comment: "VoiceOver label, e.g. Empty Hearts foundation pile"))
                .accessibilityHidden(!game.foundations[f].isEmpty)
        }
        ForEach(game.tableau.indices, id: \.self) { t in
            let frame = layout.slotFrame(for: .tableau(t))
            SlotView(kind: .tableau, size: layout.cardSize)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .accessibilityLabel(String(localized: "Empty column, only a King can go here"))
                .accessibilityHidden(!game.tableau[t].isEmpty)
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

    // MARK: - Score pops

    /// Big "+15" labels over the cards that just earned points.
    private func scorePops(placed: [PlacedCard], layout: BoardLayout) -> some View {
        ForEach(controller.scorePops) { pop in
            let point = popPosition(for: pop, placed: placed, layout: layout)
            ScorePopView(amount: pop.amount,
                         bonuses: pop.bonuses,
                         holdDuration: GameController.countUpDuration(for: pop.amount),
                         fontSize: max(40, layout.cardSize.width * 0.42))
                .position(point)
                .zIndex(4000)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func popPosition(for pop: ScorePop, placed: [PlacedCard], layout: BoardLayout) -> CGPoint {
        if let cardID = pop.cardID, let item = placed.first(where: { $0.card.id == cardID }) {
            // Over the lower part of the card itself (its big suit symbol), so no card's rank is covered.
            // Keep the charm chips beside it on screen.
            let half = pop.bonuses.isEmpty ? 0 : CGFloat(pop.bonuses.count) * 50 + 20
            let x = min(max(item.frame.midX, half), max(half, layout.size.width - half))
            return CGPoint(x: x, y: item.frame.minY + item.frame.height * 0.62)
        }
        return CGPoint(x: layout.size.width / 2, y: layout.tableauY + layout.cardSize.height)
    }

    // MARK: - Deal animation

    private func runDealAnimation() async {
        guard controller.pendingDealAnimation else { return }
        controller.pendingDealAnimation = false
        let total = controller.game.tableau.reduce(0) { $0 + $1.count }
        guard total > 0 else { return }
        dealtCount = 0
        try? await Task.sleep(for: .milliseconds(300))
        // Keep the whole deal around 1.3 seconds, however many cards there are.
        let pause = max(20, 1300 / total)
        for count in 1...total {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { dealtCount = count }
            if count % 4 == 0 { controller.playTick() }
            try? await Task.sleep(for: .milliseconds(pause))
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
        // Read as one element (callers set the label) instead of its symbol names.
        .accessibilityElement(children: .ignore)
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

/// "+15": pops in big, floats up slightly while the score counts, then fades.
struct ScorePopView: View {
    let amount: Int
    let bonuses: [CharmBonus]
    let holdDuration: Double
    let fontSize: CGFloat

    @State private var phase = Phase.appearing

    private enum Phase { case appearing, shown, fading }

    var body: some View {
        VStack(spacing: 6) {
            totalLabel
            if !bonuses.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(bonuses.enumerated()), id: \.offset) { index, bonus in
                        CharmBonusChip(bonus: bonus, delay: 0.15 * Double(index + 1), fontSize: fontSize * 0.5)
                    }
                }
            }
        }
        .scaleEffect(phase == .appearing ? 0.4 : (phase == .shown ? 1 : 1.1))
        .opacity(phase == .fading ? 0 : 1)
        .offset(y: phase == .appearing ? 12 : (phase == .shown ? -8 : -30))
        .task {
            withAnimation(.spring(duration: 0.3, bounce: 0.55)) { phase = .shown }
            // Stay put while the score counter counts up (long enough for the charm chips to flash).
            try? await Task.sleep(for: .seconds(max(holdDuration, 0.4 + 0.15 * Double(bonuses.count))))
            withAnimation(.easeIn(duration: 0.4)) { phase = .fading }
        }
    }

    private var totalLabel: some View {
        Text("+\(amount)")
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Theme.gold)
            .shadow(color: .black.opacity(0.8), radius: 2, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.7), lineWidth: 2))
            .fixedSize()
    }
}

/// One charm's contribution: its icon and "+10", flashing once when it appears.
struct CharmBonusChip: View {
    let bonus: CharmBonus
    let delay: Double
    let fontSize: CGFloat

    @State private var flash = false

    var body: some View {
        HStack(spacing: 6) {
            CharmIcon(charm: bonus.charm, size: max(30, fontSize * 1.1))
            Text("+\(bonus.amount)")
                .font(.system(size: max(22, fontSize), weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(bonus.charm.tint)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(0.7)))
        .overlay(Capsule().strokeBorder(bonus.charm.tint.opacity(flash ? 1 : 0.5), lineWidth: flash ? 3 : 1.5))
        .shadow(color: bonus.charm.tint.opacity(flash ? 0.9 : 0), radius: 12)
        .scaleEffect(flash ? 1.2 : 1)
        .fixedSize()
        .accessibilityLabel("\(bonus.charm.title) +\(bonus.amount)")
        .task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(.spring(duration: 0.2, bounce: 0.5)) { flash = true }
            try? await Task.sleep(for: .seconds(0.25))
            withAnimation(.easeOut(duration: 0.3)) { flash = false }
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
