//
//  CardView.swift
//  MaemelSolitaer
//
//  Oversized, high-contrast playing cards. The rank and suit sit large in the top strip
//  so they stay readable when cards overlap in a column.
//

import SwiftUI

struct CardView: View {
    let card: Card
    let size: CGSize
    var isHighlighted = false

    var body: some View {
        let corner = size.width * 0.09
        FlippingCard(card: card, size: size, angle: card.isFaceUp ? 0 : 180)
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.gold, lineWidth: max(4, size.width * 0.05))
                    .shadow(color: Theme.gold.opacity(0.9), radius: 8)
            }
        }
        // One element per card; callers provide the label. Hides the face of face-down cards.
        .accessibilityElement(children: .ignore)
    }
}

/// Flips a card by squeezing it horizontally and swapping sides halfway through.
/// A flat effect (no 3D perspective) keeps the card's frame — and its VoiceOver outline — exact.
private struct FlippingCard: View, Animatable {
    let card: Card
    let size: CGSize
    /// 0 = face up, 180 = face down.
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsFace = angle < 90
        ZStack {
            if showsFace {
                CardFace(card: card, size: size)
            } else {
                CardBack(size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        // Only the card's outline casts a shadow. (A `.shadow` on the whole card would also shadow
        // every letter and symbol, which popped in as the flip settled.)
        .background {
            RoundedRectangle(cornerRadius: size.width * 0.09, style: .continuous)
                .fill(Theme.cardFace)
                .shadow(color: .black.opacity(0.28), radius: 1.5, x: 0, y: 1)
        }
        .scaleEffect(x: max(0.02, abs(cos(angle * .pi / 180))), y: 1)
    }
}

struct CardFace: View {
    let card: Card
    let size: CGSize

    var body: some View {
        let w = size.width
        let h = size.height
        let shape = RoundedRectangle(cornerRadius: w * 0.09, style: .continuous)
        let ink = card.isRed ? Theme.cardRed : Theme.cardBlack

        ZStack(alignment: .top) {
            shape.fill(Theme.cardFace)
            shape.strokeBorder(Color.black.opacity(0.25), lineWidth: 1)

            // Top strip: big rank on the left, big suit on the right.
            HStack(alignment: .top, spacing: 0) {
                Text(card.rankLabel)
                    .font(.system(size: h * 0.22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Image(systemName: card.suit.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: h * 0.17, height: h * 0.17)
                    .padding(.top, h * 0.03)
                    // The symbol's built-in name for the heart is "Remove From Favorites".
                    .accessibilityLabel(card.suit.name)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, w * 0.07)
            .padding(.top, h * 0.015)

            centerArt(ink: ink)
                .frame(width: w, height: h * 0.66)
                .offset(y: h * 0.31)
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private func centerArt(ink: Color) -> some View {
        let w = size.width
        if card.rank >= 11 {
            // Face cards: a large letter in a soft frame.
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(ink.opacity(0.08))
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .strokeBorder(ink.opacity(0.35), lineWidth: max(1, w * 0.015))
                VStack(spacing: 0) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: w * 0.16))
                        .opacity(card.rank == 13 ? 1 : 0.45)
                    Text(card.rankLabel)
                        .font(.system(size: w * 0.42, weight: .bold, design: .serif))
                }
                .foregroundStyle(ink)
            }
            .padding(.horizontal, w * 0.14)
            .padding(.bottom, w * 0.12)
        } else {
            Image(systemName: card.suit.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: w * (card.rank == 1 ? 0.62 : 0.52))
                .foregroundStyle(ink)
                .accessibilityLabel(card.suit.name)
                .padding(.bottom, w * 0.08)
        }
    }
}

struct CardBack: View {
    let size: CGSize

    var body: some View {
        let w = size.width
        let outer = RoundedRectangle(cornerRadius: w * 0.09, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
        outer
            .fill(Theme.cardFace)
            .overlay {
                inner
                    .fill(LinearGradient(
                        colors: [Color(red: 0.58, green: 0.13, blue: 0.18), Color(red: 0.38, green: 0.06, blue: 0.11)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay {
                        // Drawn in a Canvas so the overshooting lines never enlarge the card's frame.
                        Canvas { context, canvasSize in
                            let pattern = DiamondPattern(spacing: max(8, w * 0.14))
                                .path(in: CGRect(origin: .zero, size: canvasSize))
                            context.stroke(pattern, with: .color(.white.opacity(0.16)), lineWidth: 1)
                        }
                        .clipShape(inner)
                    }
                    .overlay(inner.strokeBorder(Theme.gold.opacity(0.55), lineWidth: max(1, w * 0.02)))
                    .padding(w * 0.06)
            }
            .overlay(outer.strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
    }
}

/// Criss-cross lines for the card back.
struct DiamondPattern: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let span = rect.width + rect.height
        var offset: CGFloat = -rect.height
        while offset < span {
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            offset += spacing
        }
        return path
    }
}

#Preview {
    HStack {
        CardView(card: Card(suit: .hearts, rank: 1, isFaceUp: true), size: CGSize(width: 130, height: 182))
        CardView(card: Card(suit: .spades, rank: 10, isFaceUp: true), size: CGSize(width: 130, height: 182))
        CardView(card: Card(suit: .diamonds, rank: 12, isFaceUp: true), size: CGSize(width: 130, height: 182))
        CardView(card: Card(suit: .clubs, rank: 5), size: CGSize(width: 130, height: 182))
    }
    .padding()
    .background(FeltBackground(color: .forest))
}
