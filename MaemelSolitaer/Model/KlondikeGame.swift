//
//  KlondikeGame.swift
//  MaemelSolitaer
//
//  Pure, standard Klondike rules. No UI and no scoring live here.
//  Supports more columns and two decks; the rules themselves never change.
//

import Foundation

/// Identifies one pile on the table.
nonisolated enum PileID: Hashable, Codable, Sendable {
    case stock
    case waste
    case foundation(Int)
    case tableau(Int)
}

/// Everything that happened during one move, used for scoring and sound.
/// Scoring-relevant events are only reported the first time they happen so points can't be farmed.
nonisolated struct MoveEvents: Sendable {
    var newFoundationCards: [Card] = []
    var completedSuits = 0
    var revealedCards = 0
    var wasteToTableau = 0
    var newlyClearedColumns = 0
    var newKingsToEmptyColumn = 0
    var reachedFoundation = false
    var drewCards = false
    var recycledStock = false
}

/// A suggested move. A nil destination means "tap the deck".
nonisolated struct GameHint: Equatable, Sendable {
    let from: PileID
    let index: Int
    let to: PileID?
    let message: String
}

nonisolated struct KlondikeGame: Codable, Sendable {
    var stock: [Card] = []
    var waste: [Card] = []
    /// Foundation `i` always holds the suit whose raw value is `i % 4`
    /// (two-deck games have two foundation piles per suit).
    var foundations: [[Card]] = Array(repeating: [], count: 4)
    var tableau: [[Card]] = Array(repeating: [], count: 7)
    var drawCount = 1
    var moveCount = 0

    // Bookkeeping so each scoring event is rewarded only once per deal.
    var scoredFoundationCards: Set<Int> = []
    var clearedColumns: Set<Int> = []
    var kingsMovedToEmpty: Set<Int> = []

    /// An empty table with the given shape (shown while a deal is being prepared).
    static func empty(columns: Int, decks: Int, drawCount: Int) -> KlondikeGame {
        var game = KlondikeGame()
        game.drawCount = drawCount
        game.tableau = Array(repeating: [], count: columns)
        game.foundations = Array(repeating: [], count: 4 * decks)
        return game
    }

    /// Shuffles and deals a fresh game: column `n` gets `n + 1` cards, top card face up.
    static func deal(columns: Int = 7, decks: Int = 1, drawCount: Int) -> KlondikeGame {
        var cards = (0..<decks).flatMap { Card.fullDeck(deck: $0) }.shuffled()
        var game = empty(columns: columns, decks: decks, drawCount: drawCount)
        for column in 0..<columns {
            for row in 0...column {
                var card = cards.removeLast()
                card.isFaceUp = row == column
                game.tableau[column].append(card)
            }
        }
        game.stock = cards
        return game
    }

    // MARK: - Queries

    func cards(in pile: PileID) -> [Card] {
        switch pile {
        case .stock: stock
        case .waste: waste
        case .foundation(let i): foundations.indices.contains(i) ? foundations[i] : []
        case .tableau(let i): tableau.indices.contains(i) ? tableau[i] : []
        }
    }

    var isWon: Bool { foundations.allSatisfy { $0.count == 13 } }

    var faceDownCount: Int {
        tableau.reduce(0) { total, column in total + column.filter { !$0.isFaceUp }.count }
    }

    /// Auto-complete is offered once every tableau card is face up.
    var canAutoComplete: Bool { faceDownCount == 0 && !isWon }

    /// The cards picked up when grabbing `index` in `pile`, or nil if that isn't allowed.
    func movableCards(from pile: PileID, at index: Int) -> [Card]? {
        switch pile {
        case .stock:
            return nil
        case .waste:
            guard !waste.isEmpty, index == waste.count - 1 else { return nil }
            return [waste[index]]
        case .foundation(let f):
            guard foundations.indices.contains(f), !foundations[f].isEmpty,
                  index == foundations[f].count - 1 else { return nil }
            return [foundations[f][index]]
        case .tableau(let t):
            guard tableau.indices.contains(t) else { return nil }
            let column = tableau[t]
            guard column.indices.contains(index), column[index].isFaceUp else { return nil }
            let run = Array(column[index...])
            // A run must descend by one and alternate colors.
            for (upper, lower) in zip(run, run.dropFirst()) {
                guard upper.rank == lower.rank + 1, upper.isRed != lower.isRed else { return nil }
            }
            return run
        }
    }

    func canPlace(_ cards: [Card], on pile: PileID) -> Bool {
        guard let first = cards.first else { return false }
        switch pile {
        case .foundation(let f):
            guard foundations.indices.contains(f), cards.count == 1, first.suit.rawValue == f % 4 else { return false }
            if let top = foundations[f].last { return top.rank + 1 == first.rank }
            return first.rank == 1
        case .tableau(let t):
            guard tableau.indices.contains(t) else { return false }
            if let top = tableau[t].last {
                return top.isFaceUp && top.isRed != first.isRed && top.rank == first.rank + 1
            }
            return first.rank == 13
        case .stock, .waste:
            return false
        }
    }

    /// The foundation pile that can take this card right now, if any.
    func foundationSlot(for card: Card) -> PileID? {
        for f in foundations.indices where canPlace([card], on: .foundation(f)) {
            return .foundation(f)
        }
        return nil
    }

    // MARK: - Moves

    mutating func move(from source: PileID, at index: Int, to destination: PileID) -> MoveEvents? {
        guard source != destination,
              let moving = movableCards(from: source, at: index),
              canPlace(moving, on: destination) else { return nil }

        var events = MoveEvents()

        switch source {
        case .waste: waste.removeLast()
        case .foundation(let f): foundations[f].removeLast()
        case .tableau(let t): tableau[t].removeSubrange(index...)
        case .stock: return nil
        }

        switch destination {
        case .foundation(let f):
            foundations[f].append(contentsOf: moving)
            events.reachedFoundation = true
            for card in moving where !scoredFoundationCards.contains(card.id) {
                scoredFoundationCards.insert(card.id)
                events.newFoundationCards.append(card)
            }
            if foundations[f].count == 13, events.newFoundationCards.contains(where: { $0.rank == 13 }) {
                events.completedSuits = 1
            }
        case .tableau(let t):
            let wasEmpty = tableau[t].isEmpty
            tableau[t].append(contentsOf: moving)
            if source == .waste { events.wasteToTableau = 1 }
            if wasEmpty, let king = moving.first, king.rank == 13, !kingsMovedToEmpty.contains(king.id) {
                kingsMovedToEmpty.insert(king.id)
                events.newKingsToEmptyColumn = 1
            }
        case .stock, .waste:
            break
        }

        // Turn over the newly exposed card, or note an emptied column.
        if case .tableau(let t) = source {
            if tableau[t].isEmpty {
                if !clearedColumns.contains(t) {
                    clearedColumns.insert(t)
                    events.newlyClearedColumns = 1
                }
            } else if let last = tableau[t].last, !last.isFaceUp {
                tableau[t][tableau[t].count - 1].isFaceUp = true
                events.revealedCards = 1
            }
        }

        moveCount += 1
        return events
    }

    /// Turns over cards from the deck, or turns the waste back into the deck when the deck is empty.
    mutating func dealFromStock() -> MoveEvents? {
        var events = MoveEvents()
        if stock.isEmpty {
            guard !waste.isEmpty else { return nil }
            stock = waste.reversed().map { card in
                var card = card
                card.isFaceUp = false
                return card
            }
            waste.removeAll()
            events.recycledStock = true
        } else {
            for _ in 0..<min(drawCount, stock.count) {
                var card = stock.removeLast()
                card.isFaceUp = true
                waste.append(card)
            }
            events.drewCards = true
        }
        moveCount += 1
        return events
    }

    // MARK: - Assists

    /// The most helpful place for a tapped card: foundation first, then a built column, then an empty column.
    func bestDestination(from pile: PileID, at index: Int) -> PileID? {
        guard let moving = movableCards(from: pile, at: index), let first = moving.first else { return nil }

        if moving.count == 1, !isFoundation(pile), let foundation = foundationSlot(for: first) {
            return foundation
        }

        var emptyColumn: PileID?
        for t in tableau.indices where PileID.tableau(t) != pile && canPlace(moving, on: .tableau(t)) {
            if tableau[t].isEmpty {
                if emptyColumn == nil { emptyColumn = .tableau(t) }
            } else {
                return .tableau(t)
            }
        }

        // Moving a King that already sits at the bottom of a column achieves nothing.
        if case .tableau = pile, index == 0 { return nil }
        return emptyColumn
    }

    /// Finds a genuinely useful move, or nil when the player is stuck.
    func findHint() -> GameHint? {
        // 1. Anything that can go up to its foundation.
        for (pile, index) in exposedCards() {
            if let destination = foundationSlot(for: cards(in: pile)[index]) {
                return makeHint(from: pile, index: index, to: destination)
            }
        }

        // 2. Column moves that uncover a face-down card, or a card that can then go to the foundation.
        for t in tableau.indices {
            let column = tableau[t]
            guard let firstUp = column.firstIndex(where: { $0.isFaceUp }) else { continue }
            for i in firstUp..<column.count {
                guard let run = movableCards(from: .tableau(t), at: i) else { continue }
                let uncoversFaceDown = i == firstUp && i > 0
                let uncoversFoundationCard = i > firstUp && foundationSlot(for: column[i - 1]) != nil
                guard uncoversFaceDown || uncoversFoundationCard else { continue }
                for d in tableau.indices where d != t && canPlace(run, on: .tableau(d)) {
                    return makeHint(from: .tableau(t), index: i, to: .tableau(d))
                }
            }
        }

        // 3. The top deck card onto a column.
        if let top = waste.last {
            for d in tableau.indices where canPlace([top], on: .tableau(d)) {
                return makeHint(from: .waste, index: waste.count - 1, to: .tableau(d))
            }
        }

        // 4. Turn over deck cards, but only if one of them could actually be played.
        let pool = stock + waste.dropLast()
        let deckHasPlayableCard = pool.contains { card in
            foundationSlot(for: card) != nil
                || tableau.indices.contains { canPlace([card], on: .tableau($0)) }
        }
        if deckHasPlayableCard {
            let message = stock.isEmpty
                ? String(localized: "Tap the empty deck to turn the cards over again.")
                : String(localized: "Tap the deck to turn over a new card.")
            return GameHint(from: .stock, index: max(stock.count - 1, 0), to: nil, message: message)
        }
        return nil
    }

    /// Next step for auto-complete: the lowest card that can go up, otherwise a deck draw.
    func nextAutoCompleteStep() -> GameHint? {
        var best: (pile: PileID, index: Int, rank: Int, to: PileID)?
        for (pile, index) in exposedCards() {
            let card = cards(in: pile)[index]
            guard let destination = foundationSlot(for: card) else { continue }
            if card.rank < (best?.rank ?? 99) {
                best = (pile, index, card.rank, destination)
            }
        }
        if let best {
            return GameHint(from: best.pile, index: best.index, to: best.to, message: "")
        }
        if !stock.isEmpty || !waste.isEmpty {
            return GameHint(from: .stock, index: 0, to: nil, message: "")
        }
        return nil
    }

    // MARK: - Helpers

    private func isFoundation(_ pile: PileID) -> Bool {
        if case .foundation = pile { return true }
        return false
    }

    /// Top waste card and the top card of every column.
    private func exposedCards() -> [(PileID, Int)] {
        var result: [(PileID, Int)] = []
        if !waste.isEmpty { result.append((.waste, waste.count - 1)) }
        for t in tableau.indices where !tableau[t].isEmpty {
            result.append((.tableau(t), tableau[t].count - 1))
        }
        return result
    }

    private func makeHint(from pile: PileID, index: Int, to destination: PileID) -> GameHint {
        let card = cards(in: pile)[index].spokenName
        // Whole sentences (not fragments) so each language can order the words naturally.
        let message: String
        switch destination {
        case .tableau(let t):
            if let top = tableau[t].last {
                message = String(localized: "Move the \(card) onto the \(top.spokenName).",
                                 comment: "Hint. First: card to move, second: card it goes onto, e.g. 7 of Hearts / 8 of Spades")
            } else {
                message = String(localized: "Move the \(card) into the empty column.", comment: "Hint. The card to move, e.g. King of Clubs")
            }
        case .foundation, .stock, .waste:
            message = String(localized: "Move the \(card) up to its foundation pile.", comment: "Hint. The card to move, e.g. Ace of Hearts")
        }
        return GameHint(from: pile, index: index, to: destination, message: message)
    }
}
