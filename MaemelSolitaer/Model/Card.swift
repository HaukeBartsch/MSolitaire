//
//  Card.swift
//  MaemelSolitaer
//

import Foundation

/// The four French suits. The raw value doubles as the foundation slot index.
nonisolated enum Suit: Int, CaseIterable, Codable, Hashable, Sendable {
    case spades, hearts, diamonds, clubs

    var isRed: Bool { self == .hearts || self == .diamonds }

    /// SF Symbol used to draw the suit.
    var symbolName: String {
        switch self {
        case .spades: "suit.spade.fill"
        case .hearts: "suit.heart.fill"
        case .diamonds: "suit.diamond.fill"
        case .clubs: "suit.club.fill"
        }
    }

    /// Text glyph (forced to text presentation so it never renders as an emoji).
    var glyph: String {
        switch self {
        case .spades: "\u{2660}\u{FE0E}"
        case .hearts: "\u{2665}\u{FE0E}"
        case .diamonds: "\u{2666}\u{FE0E}"
        case .clubs: "\u{2663}\u{FE0E}"
        }
    }

    var name: String {
        switch self {
        case .spades: "Spades"
        case .hearts: "Hearts"
        case .diamonds: "Diamonds"
        case .clubs: "Clubs"
        }
    }
}

/// A single playing card. Rank runs from 1 (Ace) to 13 (King).
nonisolated struct Card: Identifiable, Codable, Hashable, Sendable {
    let suit: Suit
    let rank: Int
    var isFaceUp = false

    /// Stable identity (0...51) independent of whether the card is face up.
    var id: Int { suit.rawValue * 13 + rank - 1 }

    var isRed: Bool { suit.isRed }

    var rankLabel: String {
        switch rank {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: "\(rank)"
        }
    }

    var rankName: String {
        switch rank {
        case 1: "Ace"
        case 11: "Jack"
        case 12: "Queen"
        case 13: "King"
        default: "\(rank)"
        }
    }

    /// Human readable name, e.g. "7 of Hearts".
    var spokenName: String { "\(rankName) of \(suit.name)" }

    static func fullDeck() -> [Card] {
        Suit.allCases.flatMap { suit in
            (1...13).map { Card(suit: suit, rank: $0) }
        }
    }
}
