//
//  Components.swift
//  MaemelSolitaer
//
//  Small reusable pieces: charm badges, condition cards, round progress and celebrations.
//

import SwiftUI

extension Charm {
    var tint: Color {
        switch self {
        case .royalCourt, .suitCollector, .grandFinale: Theme.gold
        case .heartOfGold, .diamondDust: Color(red: 1.0, green: 0.52, blue: 0.52)
        case .spadeSmith, .luckyClover: Color(red: 0.78, green: 0.86, blue: 1.0)
        case .foundationFriend, .aceStarter, .kingdomBuilder: Color(red: 0.55, green: 0.85, blue: 1.0)
        case .brightEyes, .tidyTable, .deckHelper: Color(red: 0.6, green: 0.95, blue: 0.65)
        case .freeUndo, .wiseOwl, .headStart: Color(red: 0.86, green: 0.72, blue: 1.0)
        }
    }
}

struct CharmIcon: View {
    let charm: Charm
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(charm.tint.opacity(0.22))
            Circle().strokeBorder(charm.tint, lineWidth: 2)
            Image(systemName: charm.symbolName)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(charm.tint)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(charm.title)
    }
}

/// Charm with its name and description, for lists.
struct CharmRow: View {
    let charm: Charm

    var body: some View {
        HStack(spacing: 14) {
            CharmIcon(charm: charm, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(charm.title)
                    .font(Theme.rounded(.title3, weight: .bold))
                Text(charm.detail)
                    .font(Theme.rounded(.body))
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ConditionCard: View {
    let condition: StageCondition

    var body: some View {
        let tint = condition.isChallenge ? Color(red: 1.0, green: 0.68, blue: 0.45) : Theme.success
        HStack(spacing: 18) {
            Image(systemName: condition.symbolName)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(tint.opacity(0.18)))
            VStack(alignment: .leading, spacing: 4) {
                Text(condition.isChallenge ? String(localized: "Boss Rule") : String(localized: "This Round"))
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                Text(condition.title)
                    .font(Theme.rounded(.title, weight: .bold))
                Text(condition.detail)
                    .font(Theme.rounded(.title3))
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .panelBackground()
        .accessibilityElement(children: .combine)
    }
}

/// Three steps (Warm-Up, Main, Boss) with the current one highlighted.
struct StageProgressDots: View {
    let current: StageKind

    var body: some View {
        HStack(spacing: 28) {
            ForEach(StageKind.allCases, id: \.self) { kind in
                let isDone = kind.rawValue < current.rawValue
                let isCurrent = kind == current
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isCurrent ? Theme.gold : Color.white.opacity(isDone ? 0.35 : 0.12))
                        Image(systemName: isDone ? "checkmark" : kind.symbolName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(isCurrent ? Color.black : Color.white)
                    }
                    .frame(width: 58, height: 58)
                    Text(kind.shortTitle)
                        .font(Theme.rounded(.headline, weight: isCurrent ? .bold : .regular))
                        .opacity(isCurrent ? 1 : 0.75)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Round \(current.rawValue + 1) of 3, \(current.title)")
    }
}

/// Rewarding cascade of cards tumbling down the screen.
struct CascadingCardsView: View {
    private struct Piece: Identifiable {
        let id: Int
        let card: Card
        let x: CGFloat
        let spin: Double
        let duration: Double
        let delay: Double
    }

    @State private var pieces: [Piece] = (0..<20).map { i in
        let suit = Suit.allCases[i % 4]
        return Piece(
            id: i,
            card: Card(suit: suit, rank: Int.random(in: 1...13), isFaceUp: true),
            x: CGFloat.random(in: 0.05...0.95),
            spin: Double.random(in: -360...360),
            duration: Double.random(in: 2.6...4.0),
            delay: Double(i) * 0.2
        )
    }
    @State private var falling = false

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: 86, height: 120)
            ZStack {
                ForEach(pieces) { piece in
                    CardView(card: piece.card, size: size)
                        .rotationEffect(.degrees(falling ? piece.spin : 0))
                        .position(
                            x: proxy.size.width * piece.x,
                            y: falling ? proxy.size.height + size.height : -size.height
                        )
                        .animation(
                            .easeIn(duration: piece.duration).repeatForever(autoreverses: false).delay(piece.delay),
                            value: falling
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { falling = true }
    }
}

/// Banner for hints and friendly notices.
struct MessageBanner: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        let text = controller.activeHint?.message ?? controller.notice
        ZStack {
            if let text {
                HStack(spacing: 12) {
                    Image(systemName: controller.activeHint != nil ? "lightbulb.fill" : "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    Text(text)
                        .font(Theme.rounded(.title3, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2))
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(text)
            }
        }
        .animation(.spring(duration: 0.35), value: text)
    }
}

/// A charm icon that pulses and glows whenever the charm adds points.
struct FlashingCharmIcon: View {
    @Environment(GameController.self) private var controller
    let charm: Charm
    var size: CGFloat = 44
    @State private var showsAmount = false

    var body: some View {
        let flashCount = controller.charmFlashes[charm] ?? 0
        let tint = charm.tint
        CharmIcon(charm: charm, size: size)
            .keyframeAnimator(initialValue: 0.0, trigger: flashCount) { content, glow in
                content
                    .scaleEffect(1 + 0.3 * glow)
                    .shadow(color: tint.opacity(glow), radius: 14)
            } keyframes: { _ in
                CubicKeyframe(1.0, duration: 0.12)
                CubicKeyframe(0.0, duration: 0.4)
            }
            .overlay(alignment: .top) {
                if showsAmount, let amount = controller.charmFlashAmounts[charm] {
                    Text("+\(amount)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(charm.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.85)))
                        .overlay(Capsule().strokeBorder(charm.tint, lineWidth: 2))
                        .fixedSize()
                        .offset(y: -34)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .zIndex(showsAmount ? 10 : 0)
            .task(id: flashCount) {
                // Show the amount for about a second after each flash (not on first appearance).
                guard flashCount > 0 else { return }
                withAnimation(.spring(duration: 0.25, bounce: 0.4)) { showsAmount = true }
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { showsAmount = false }
            }
    }
}
