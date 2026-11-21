//
//  Theme.swift
//  MaemelSolitaer
//
//  Colors, fonts and reusable styles. Everything is high-contrast and generously sized.
//

import SwiftUI

nonisolated enum Theme {
    static let gold = Color(red: 0.99, green: 0.80, blue: 0.32)
    static let success = Color(red: 0.47, green: 0.90, blue: 0.56)
    static let cardFace = Color(red: 1.0, green: 0.99, blue: 0.96)
    static let cardRed = Color(red: 0.80, green: 0.04, blue: 0.10)
    static let cardBlack = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let panelFill = Color.black.opacity(0.32)
    static let panelStroke = Color.white.opacity(0.14)
    static let sheetBackground = Color(red: 0.09, green: 0.13, blue: 0.15)

    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension TableColor {
    /// Matte felt gradients — soft and non-glare.
    var colors: [Color] {
        switch self {
        case .forest: [Color(red: 0.13, green: 0.38, blue: 0.25), Color(red: 0.07, green: 0.25, blue: 0.16)]
        case .navy: [Color(red: 0.15, green: 0.22, blue: 0.38), Color(red: 0.08, green: 0.12, blue: 0.25)]
        case .slate: [Color(red: 0.24, green: 0.28, blue: 0.32), Color(red: 0.14, green: 0.17, blue: 0.20)]
        }
    }
}

struct FeltBackground: View {
    let color: TableColor

    var body: some View {
        ZStack {
            LinearGradient(colors: color.colors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.clear, .black.opacity(0.22)], center: .center, startRadius: 250, endRadius: 1000)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: color)
    }
}

struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Theme.panelFill))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.panelStroke, lineWidth: 1.5)
            )
    }
}

extension View {
    func panelBackground(cornerRadius: CGFloat = 24) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }
}

/// Large, high-contrast button used throughout the menus.
struct BigButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        BigButtonBody(configuration: configuration, kind: kind)
    }
}

private struct BigButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: BigButtonStyle.Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let compact = sizeClass == .compact
        configuration.label
            .font(Theme.rounded(.title2, weight: .bold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .foregroundStyle(kind == .primary ? Color.black : Color.white)
            .padding(.horizontal, compact ? 14 : 24)
            .padding(.vertical, compact ? 10 : 14)
            .frame(maxWidth: .infinity, minHeight: compact ? 62 : 72)
            .background(shape.fill(kind == .primary ? Theme.gold : Color.white.opacity(0.14)))
            .overlay(shape.strokeBorder(Color.white.opacity(kind == .primary ? 0 : 0.45), lineWidth: 2))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A gentle sideways wobble used when a card can't move anywhere.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 9 * sin(animatableData * .pi * 4), y: 0))
    }
}
