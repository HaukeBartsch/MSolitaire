//
//  Progression.swift
//  MaemelSolitaer
//
//  Chapters, rounds, round conditions, charms and scoring.
//  None of this changes how cards are played — it only changes how points are earned.
//

import Foundation

/// The three rounds of every chapter (inspired by small blind / big blind / boss).
nonisolated enum StageKind: Int, Codable, CaseIterable, Sendable {
    case small, big, boss

    var title: String {
        switch self {
        case .small: "Warm-Up Round"
        case .big: "Main Round"
        case .boss: "Boss Round"
        }
    }

    var shortTitle: String {
        switch self {
        case .small: "Warm-Up"
        case .big: "Main"
        case .boss: "Boss"
        }
    }

    var symbolName: String {
        switch self {
        case .small: "leaf.fill"
        case .big: "star.fill"
        case .boss: "crown.fill"
        }
    }

    var targetMultiplier: Double {
        switch self {
        case .small: 1.0
        case .big: 1.4
        case .boss: 1.8
        }
    }
}

/// A gentle, easy-to-understand rule for one round.
nonisolated enum StageCondition: String, Codable, CaseIterable, Sendable {
    case calmTable
    case doubleHearts, doubleDiamonds, doubleSpades, doubleClubs
    case revealBonus
    case aceParade
    case columnBonus
    case moveBudget
    // Boss rounds: mild challenges.
    case costlyUndo
    case costlyHints
    case drawThree

    static let moveBudgetLimit = 150

    var title: String {
        switch self {
        case .calmTable: "Calm Table"
        case .doubleHearts: "Hearts Shine"
        case .doubleDiamonds: "Diamonds Sparkle"
        case .doubleSpades: "Spades Shine"
        case .doubleClubs: "Clubs Bloom"
        case .revealBonus: "Peek-a-Boo"
        case .aceParade: "Ace Parade"
        case .columnBonus: "Clear the Way"
        case .moveBudget: "Tidy Play"
        case .costlyUndo: "Careful Steps"
        case .costlyHints: "Think It Through"
        case .drawThree: "Three at a Time"
        }
    }

    var detail: String {
        switch self {
        case .calmTable: "No special rules. Just enjoy the game."
        case .doubleHearts: "Hearts give double points when moved to the foundation."
        case .doubleDiamonds: "Diamonds give double points when moved to the foundation."
        case .doubleSpades: "Spades give double points when moved to the foundation."
        case .doubleClubs: "Clubs give double points when moved to the foundation."
        case .revealBonus: "Every face-down card you turn over gives 15 extra points."
        case .aceParade: "Every Ace moved to the foundation gives 40 extra points."
        case .columnBonus: "Earn 50 extra points each time you empty a column."
        case .moveBudget: "Clear the whole board within \(Self.moveBudgetLimit) moves for a 150 point bonus."
        case .costlyUndo: "Each Undo costs 15 points this round."
        case .costlyHints: "Each Hint costs 10 points this round."
        case .drawThree: "Turn over 3 deck cards at a time. Every card moved to the foundation gives 5 extra points."
        }
    }

    var symbolName: String {
        switch self {
        case .calmTable: "cup.and.saucer.fill"
        case .doubleHearts: "suit.heart.fill"
        case .doubleDiamonds: "suit.diamond.fill"
        case .doubleSpades: "suit.spade.fill"
        case .doubleClubs: "suit.club.fill"
        case .revealBonus: "eye.fill"
        case .aceParade: "a.circle.fill"
        case .columnBonus: "square.dashed"
        case .moveBudget: "flag.checkered"
        case .costlyUndo: "arrow.uturn.backward"
        case .costlyHints: "lightbulb"
        case .drawThree: "rectangle.stack.fill"
        }
    }

    var isChallenge: Bool { [.costlyUndo, .costlyHints, .drawThree].contains(self) }

    var doubledSuit: Suit? {
        switch self {
        case .doubleHearts: .hearts
        case .doubleDiamonds: .diamonds
        case .doubleSpades: .spades
        case .doubleClubs: .clubs
        default: nil
        }
    }

    static func random(for kind: StageKind, ante: Int, playerDrawsThree: Bool) -> StageCondition {
        let pool: [StageCondition]
        switch kind {
        case .small:
            pool = [.calmTable, .doubleHearts, .doubleDiamonds, .doubleSpades, .doubleClubs, .revealBonus, .aceParade]
        case .big:
            pool = [.doubleHearts, .doubleDiamonds, .doubleSpades, .doubleClubs, .revealBonus, .columnBonus, .moveBudget, .aceParade]
        case .boss:
            var bosses: [StageCondition] = [.costlyUndo, .costlyHints]
            if ante >= 2 && !playerDrawsThree { bosses.append(.drawThree) }
            pool = bosses
        }
        return pool.randomElement() ?? .calmTable
    }
}

/// A simple passive upgrade that lasts for the whole journey.
nonisolated enum Charm: String, Codable, CaseIterable, Identifiable, Sendable {
    case royalCourt, foundationFriend, brightEyes
    case heartOfGold, spadeSmith, diamondDust, luckyClover
    case aceStarter, tidyTable, freeUndo, wiseOwl, headStart
    case grandFinale, deckHelper, suitCollector, kingdomBuilder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .royalCourt: "Royal Court"
        case .foundationFriend: "Foundation Friend"
        case .brightEyes: "Bright Eyes"
        case .heartOfGold: "Heart of Gold"
        case .spadeSmith: "Spade Smith"
        case .diamondDust: "Diamond Dust"
        case .luckyClover: "Lucky Clover"
        case .aceStarter: "Ace Starter"
        case .tidyTable: "Tidy Table"
        case .freeUndo: "Second Chance"
        case .wiseOwl: "Wise Owl"
        case .headStart: "Head Start"
        case .grandFinale: "Grand Finale"
        case .deckHelper: "Deck Helper"
        case .suitCollector: "Suit Collector"
        case .kingdomBuilder: "Kingdom Builder"
        }
    }

    var detail: String {
        switch self {
        case .royalCourt: "Kings give +50 points when moved to the foundation."
        case .foundationFriend: "+10 points for every card moved to the foundation."
        case .brightEyes: "+10 points for every face-down card you turn over."
        case .heartOfGold: "Hearts give +15 points when moved to the foundation."
        case .spadeSmith: "Spades give +15 points when moved to the foundation."
        case .diamondDust: "Diamonds give +15 points when moved to the foundation."
        case .luckyClover: "Clubs give +15 points when moved to the foundation."
        case .aceStarter: "Aces give +30 points when moved to the foundation."
        case .tidyTable: "+40 points every time you empty a column."
        case .freeUndo: "Undo moves are always free."
        case .wiseOwl: "Hints are always free."
        case .headStart: "Begin every round with 50 points."
        case .grandFinale: "+200 points when you clear the whole board."
        case .deckHelper: "+10 points for every deck card played onto a column."
        case .suitCollector: "+100 points for each suit you complete from Ace to King."
        case .kingdomBuilder: "+25 points when a King moves into an empty column."
        }
    }

    var symbolName: String {
        switch self {
        case .royalCourt: "crown.fill"
        case .foundationFriend: "square.stack.3d.up.fill"
        case .brightEyes: "eye.fill"
        case .heartOfGold: "suit.heart.fill"
        case .spadeSmith: "suit.spade.fill"
        case .diamondDust: "suit.diamond.fill"
        case .luckyClover: "suit.club.fill"
        case .aceStarter: "a.circle.fill"
        case .tidyTable: "sparkles"
        case .freeUndo: "arrow.uturn.backward.circle.fill"
        case .wiseOwl: "lightbulb.fill"
        case .headStart: "flag.fill"
        case .grandFinale: "star.fill"
        case .deckHelper: "rectangle.stack.fill"
        case .suitCollector: "checkmark.seal.fill"
        case .kingdomBuilder: "building.columns.fill"
        }
    }

    static func suitCharm(for suit: Suit) -> Charm {
        switch suit {
        case .hearts: .heartOfGold
        case .spades: .spadeSmith
        case .diamonds: .diamondDust
        case .clubs: .luckyClover
        }
    }
}

/// Buckets used for the end-of-round score tally.
nonisolated enum ScoreCategory: String, Codable, CaseIterable, CodingKeyRepresentable, Sendable {
    case foundation, reveals, deck, charms, roundBonus, boardClear, penalties

    var title: String {
        switch self {
        case .foundation: "Cards to the foundation"
        case .reveals: "Cards turned over"
        case .deck: "Deck cards played"
        case .charms: "Charm bonuses"
        case .roundBonus: "Round bonus"
        case .boardClear: "Board cleared"
        case .penalties: "Undo and hint costs"
        }
    }

    var symbolName: String {
        switch self {
        case .foundation: "square.stack.3d.up.fill"
        case .reveals: "eye.fill"
        case .deck: "rectangle.stack.fill"
        case .charms: "sparkles"
        case .roundBonus: "gift.fill"
        case .boardClear: "star.fill"
        case .penalties: "arrow.uturn.backward"
        }
    }
}

nonisolated enum Scoring {
    static let foundationPoints = 10
    static let revealPoints = 5
    static let deckPoints = 5
    static let boardClearPoints = 250
    static let headStartPoints = 50

    /// Target score for a round. Grows gently each chapter.
    static func target(ante: Int, kind: StageKind) -> Int {
        let base = 150.0 * pow(1.3, Double(max(ante, 1) - 1))
        return Int((base * kind.targetMultiplier / 10).rounded()) * 10
    }

    static func undoCost(charms: [Charm], condition: StageCondition) -> Int {
        if charms.contains(.freeUndo) { return 0 }
        return condition == .costlyUndo ? 15 : 5
    }

    static func hintCost(charms: [Charm], condition: StageCondition) -> Int {
        if charms.contains(.wiseOwl) { return 0 }
        return condition == .costlyHints ? 10 : 0
    }

    static func points(for events: MoveEvents, charms: [Charm], condition: StageCondition) -> [ScoreCategory: Int] {
        var result: [ScoreCategory: Int] = [:]
        func add(_ category: ScoreCategory, _ value: Int) {
            if value != 0 { result[category, default: 0] += value }
        }

        for card in events.newFoundationCards {
            var charmBonus = 0
            if charms.contains(.foundationFriend) { charmBonus += 10 }
            if card.rank == 1, charms.contains(.aceStarter) { charmBonus += 30 }
            if card.rank == 13, charms.contains(.royalCourt) { charmBonus += 50 }
            if charms.contains(Charm.suitCharm(for: card.suit)) { charmBonus += 15 }
            add(.foundation, foundationPoints)
            add(.charms, charmBonus)

            var roundBonus = 0
            if condition.doubledSuit == card.suit { roundBonus += foundationPoints + charmBonus }
            if condition == .aceParade, card.rank == 1 { roundBonus += 40 }
            if condition == .drawThree { roundBonus += 5 }
            add(.roundBonus, roundBonus)
        }

        if charms.contains(.suitCollector) { add(.charms, 100 * events.completedSuits) }

        let reveals = events.revealedCards
        add(.reveals, revealPoints * reveals)
        if charms.contains(.brightEyes) { add(.charms, 10 * reveals) }
        if condition == .revealBonus { add(.roundBonus, 15 * reveals) }

        add(.deck, deckPoints * events.wasteToTableau)
        if charms.contains(.deckHelper) { add(.charms, 10 * events.wasteToTableau) }

        if charms.contains(.tidyTable) { add(.charms, 40 * events.newlyClearedColumns) }
        if condition == .columnBonus { add(.roundBonus, 50 * events.newlyClearedColumns) }

        if charms.contains(.kingdomBuilder) { add(.charms, 25 * events.newKingsToEmptyColumn) }
        return result
    }

    static func boardClearAward(moveCount: Int, charms: [Charm], condition: StageCondition) -> [ScoreCategory: Int] {
        var result: [ScoreCategory: Int] = [.boardClear: boardClearPoints]
        if charms.contains(.grandFinale) { result[.charms] = 200 }
        if condition == .moveBudget, moveCount <= StageCondition.moveBudgetLimit { result[.roundBonus] = 150 }
        return result
    }
}

/// The player's journey through the chapters.
nonisolated struct RunState: Codable, Sendable {
    static let chapterCount = 8

    var ante = 1
    var stage: StageKind = .small
    var condition: StageCondition = .calmTable
    var charms: [Charm] = []
    var totalScore = 0
    var roundsCleared = 0
    var offeredCharms: [Charm] = []
    var hasCompletedJourney = false

    var target: Int { Scoring.target(ante: ante, kind: stage) }

    func makeCharmOffer() -> [Charm] {
        Array(Charm.allCases.filter { !charms.contains($0) }.shuffled().prefix(3))
    }
}
