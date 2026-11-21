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
        case .spades: String(localized: "Spades")
        case .hearts: String(localized: "Hearts")
        case .diamonds: String(localized: "Diamonds")
        case .clubs: String(localized: "Clubs")
        }
    }
}

/// A single playing card. Rank runs from 1 (Ace) to 13 (King).
/// `deck` tells apart the two copies of a card in two-deck games.
nonisolated struct Card: Identifiable, Codable, Hashable, Sendable {
    let suit: Suit
    let rank: Int
    var deck = 0
    var isFaceUp = false

    /// Stable identity (0...103) independent of whether the card is face up.
    var id: Int { deck * 52 + suit.rawValue * 13 + rank - 1 }

    var isRed: Bool { suit.isRed }

    var rankLabel: String {
        switch rank {
        case 1: String(localized: "A", comment: "Card corner letter for an Ace")
        case 11: String(localized: "J", comment: "Card corner letter for a Jack")
        case 12: String(localized: "Q", comment: "Card corner letter for a Queen")
        case 13: String(localized: "K", comment: "Card corner letter for a King")
        default: "\(rank)"
        }
    }

    var rankName: String {
        switch rank {
        case 1: String(localized: "Ace")
        case 11: String(localized: "Jack")
        case 12: String(localized: "Queen")
        case 13: String(localized: "King")
        default: "\(rank)"
        }
    }

    /// Human readable name, e.g. "7 of Hearts".
    var spokenName: String {
        String(localized: "\(rankName) of \(suit.name)", comment: "Card name, e.g. 7 of Hearts. First: rank name, second: suit name")
    }

    static func fullDeck(deck: Int = 0) -> [Card] {
        Suit.allCases.flatMap { suit in
            (1...13).map { Card(suit: suit, rank: $0, deck: deck) }
        }
    }
}
