//
//  Progression.swift
//  MaemelSolitaer
//
//  Chapters, rounds, round conditions, charms and scoring.
//  None of this changes how cards are played — it only changes how points are earned.
//

import Foundation

/// How big and challenging the table is. The rules are always standard Klondike;
/// harder levels simply add more card stacks.
nonisolated enum Difficulty: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable, Sendable {
    case easy, medium, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        }
    }

    var detail: String {
        switch self {
        case .easy: String(localized: "The classic game: one deck and 7 columns.")
        case .medium: String(localized: "One deck and 8 columns. More cards start face down and the deck is smaller.")
        case .hard: String(localized: "Two decks, 9 columns and 8 foundation piles. A long game with higher targets and smaller cards.")
        }
    }

    var tableSummary: String {
        switch self {
        case .easy: String(localized: "52 cards · 7 columns · 4 foundations")
        case .medium: String(localized: "52 cards · 8 columns · 4 foundations")
        case .hard: String(localized: "104 cards · 9 columns · 8 foundations")
        }
    }

    var symbolName: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "flame.fill"
        case .hard: "mountain.2.fill"
        }
    }

    var deckCount: Int { self == .hard ? 2 : 1 }
    var columnCount: Int {
        switch self {
        case .easy: 7
        case .medium: 8
        case .hard: 9
        }
    }
    var foundationCount: Int { 4 * deckCount }

    /// Targets scale with the number of points a table can give.
    var targetMultiplier: Double {
        switch self {
        case .easy: 1.0
        case .medium: 1.35
        case .hard: 2.4
        }
    }

    /// Wanted share of random-choice games that clear the board, per round of a chapter.
    /// High = many sequences of choices win (forgiving). Low = only a few exact sequences win.
    /// Bands are calibrated per table size (measured on random deals) and narrow with every round.
    func winRateBand(for stage: StageKind) -> ClosedRange<Double> {
        switch (self, stage) {
        case (.easy, .small): 0.20...1.0
        case (.easy, .big): 0.05...0.20
        case (.easy, .boss): 0.0...0.05
        case (.medium, .small): 0.03...1.0
        case (.medium, .big): 0.005...0.03
        case (.medium, .boss): 0.0...0.005
        case (.hard, .small): 0.85...1.0
        case (.hard, .big): 0.65...0.85
        case (.hard, .boss): 0.0...0.65
        }
    }

    /// Random games played to measure a deal (fewer on the big table, where games are long).
    var measurePlayouts: Int { self == .hard ? 30 : 60 }

    /// Search budget for proving a deal can be won.
    var solverNodeLimit: Int {
        switch self {
        case .easy: 5_000
        case .medium: 10_000
        case .hard: 20_000
        }
    }
}

/// The three rounds of every chapter (inspired by small blind / big blind / boss).
nonisolated enum StageKind: Int, Codable, CaseIterable, Sendable {
    case small, big, boss

    var title: String {
        switch self {
        case .small: String(localized: "Warm-Up Round")
        case .big: String(localized: "Main Round")
        case .boss: String(localized: "Boss Round")
        }
    }

    var shortTitle: String {
        switch self {
        case .small: String(localized: "Warm-Up")
        case .big: String(localized: "Main")
        case .boss: String(localized: "Boss")
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
        case .calmTable: String(localized: "Calm Table")
        case .doubleHearts: String(localized: "Hearts Shine")
        case .doubleDiamonds: String(localized: "Diamonds Sparkle")
        case .doubleSpades: String(localized: "Spades Shine")
        case .doubleClubs: String(localized: "Clubs Bloom")
        case .revealBonus: String(localized: "Peek-a-Boo")
        case .aceParade: String(localized: "Ace Parade")
        case .columnBonus: String(localized: "Clear the Way")
        case .moveBudget: String(localized: "Tidy Play")
        case .costlyUndo: String(localized: "Careful Steps")
        case .costlyHints: String(localized: "Think It Through")
        case .drawThree: String(localized: "Three at a Time")
        }
    }

    var detail: String {
        switch self {
        case .calmTable: String(localized: "No special rules. Just enjoy the game.")
        case .doubleHearts: String(localized: "Hearts give double points when moved to the foundation.")
        case .doubleDiamonds: String(localized: "Diamonds give double points when moved to the foundation.")
        case .doubleSpades: String(localized: "Spades give double points when moved to the foundation.")
        case .doubleClubs: String(localized: "Clubs give double points when moved to the foundation.")
        case .revealBonus: String(localized: "Every face-down card you turn over gives 15 extra points.")
        case .aceParade: String(localized: "Every Ace moved to the foundation gives 40 extra points.")
        case .columnBonus: String(localized: "Earn 50 extra points each time you empty a column.")
        case .moveBudget: String(localized: "Clear the whole board within \(Self.moveBudgetLimit) moves for a 150 point bonus.")
        case .costlyUndo: String(localized: "Each Undo costs 15 points this round.")
        case .costlyHints: String(localized: "Each Hint costs 10 points this round.")
        case .drawThree: String(localized: "Turn over 3 deck cards at a time. Every card moved to the foundation gives 5 extra points.")
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
        case .royalCourt: String(localized: "Royal Court")
        case .foundationFriend: String(localized: "Foundation Friend")
        case .brightEyes: String(localized: "Bright Eyes")
        case .heartOfGold: String(localized: "Heart of Gold")
        case .spadeSmith: String(localized: "Spade Smith")
        case .diamondDust: String(localized: "Diamond Dust")
        case .luckyClover: String(localized: "Lucky Clover")
        case .aceStarter: String(localized: "Ace Starter")
        case .tidyTable: String(localized: "Tidy Table")
        case .freeUndo: String(localized: "Second Chance")
        case .wiseOwl: String(localized: "Wise Owl")
        case .headStart: String(localized: "Head Start")
        case .grandFinale: String(localized: "Grand Finale")
        case .deckHelper: String(localized: "Deck Helper")
        case .suitCollector: String(localized: "Suit Collector")
        case .kingdomBuilder: String(localized: "Kingdom Builder")
        }
    }

    var detail: String {
        switch self {
        case .royalCourt: String(localized: "Kings give +50 points when moved to the foundation.")
        case .foundationFriend: String(localized: "+10 points for every card moved to the foundation.")
        case .brightEyes: String(localized: "+10 points for every face-down card you turn over.")
        case .heartOfGold: String(localized: "Hearts give +15 points when moved to the foundation.")
        case .spadeSmith: String(localized: "Spades give +15 points when moved to the foundation.")
        case .diamondDust: String(localized: "Diamonds give +15 points when moved to the foundation.")
        case .luckyClover: String(localized: "Clubs give +15 points when moved to the foundation.")
        case .aceStarter: String(localized: "Aces give +30 points when moved to the foundation.")
        case .tidyTable: String(localized: "+40 points every time you empty a column.")
        case .freeUndo: String(localized: "Undo moves are always free.")
        case .wiseOwl: String(localized: "Hints are always free.")
        case .headStart: String(localized: "Begin every round with 50 points.")
        case .grandFinale: String(localized: "+200 points when you clear the whole board.")
        case .deckHelper: String(localized: "+10 points for every deck card played onto a column.")
        case .suitCollector: String(localized: "+100 points for each suit you complete from Ace to King.")
        case .kingdomBuilder: String(localized: "+25 points when a King moves into an empty column.")
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
        case .foundation: String(localized: "Cards to the foundation")
        case .reveals: String(localized: "Cards turned over")
        case .deck: String(localized: "Deck cards played")
        case .charms: String(localized: "Charm bonuses")
        case .roundBonus: String(localized: "Round bonus")
        case .boardClear: String(localized: "Board cleared")
        case .penalties: String(localized: "Undo and hint costs")
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

/// Points one charm added to a move, shown next to the card and flashed in the charm panel.
nonisolated struct CharmBonus: Equatable, Sendable {
    let charm: Charm
    let amount: Int
}

nonisolated enum Scoring {
    /// What each charm added for a move. Mirrors the charm part of `points(for:charms:condition:)`.
    static func charmBonuses(for events: MoveEvents, charms: [Charm]) -> [CharmBonus] {
        var amounts: [Charm: Int] = [:]
        func add(_ charm: Charm, _ value: Int) {
            if value != 0, charms.contains(charm) { amounts[charm, default: 0] += value }
        }
        for card in events.newFoundationCards {
            add(.foundationFriend, 10)
            if card.rank == 1 { add(.aceStarter, 30) }
            if card.rank == 13 { add(.royalCourt, 50) }
            add(Charm.suitCharm(for: card.suit), 15)
        }
        add(.suitCollector, 100 * events.completedSuits)
        add(.brightEyes, 10 * events.revealedCards)
        add(.deckHelper, 10 * events.wasteToTableau)
        add(.tidyTable, 40 * events.newlyClearedColumns)
        add(.kingdomBuilder, 25 * events.newKingsToEmptyColumn)
        return Charm.allCases.compactMap { charm in
            amounts[charm].map { CharmBonus(charm: charm, amount: $0) }
        }
    }

    static func boardClearCharmBonuses(charms: [Charm]) -> [CharmBonus] {
        charms.contains(.grandFinale) ? [CharmBonus(charm: .grandFinale, amount: 200)] : []
    }

    static let foundationPoints = 10
    static let revealPoints = 5
    static let deckPoints = 5
    static let boardClearPoints = 250
    static let headStartPoints = 50

    /// Target score for a round. Grows gently each chapter.
    static func target(ante: Int, kind: StageKind, difficulty: Difficulty = .easy) -> Int {
        let base = 150.0 * pow(1.3, Double(max(ante, 1) - 1))
        return Int((base * kind.targetMultiplier * difficulty.targetMultiplier / 10).rounded()) * 10
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
    /// Charm slots form a 3 × 3 grid; a full grid means swapping one out for a new one.
    static let maxCharms = 9

    var difficulty: Difficulty = .easy
    var ante = 1
    var stage: StageKind = .small
    var condition: StageCondition = .calmTable
    var charms: [Charm] = []
    var totalScore = 0
    var roundsCleared = 0
    var offeredCharms: [Charm] = []
    var hasCompletedJourney = false
    // Optional so saves from before this feature still load.
    private var storedCharmPicks: Int?
    private var storedBoardCleared: Bool?

    /// Charm choices still to make after the round just cleared (2 when the whole board was cleared).
    var charmPicksRemaining: Int {
        get { storedCharmPicks ?? 1 }
        set { storedCharmPicks = newValue }
    }

    /// Whether the round just cleared ended with every card on the foundations.
    var boardWasCleared: Bool {
        get { storedBoardCleared ?? false }
        set { storedBoardCleared = newValue }
    }

    static let charmPicksForClearedBoard = 2

    var target: Int { Scoring.target(ante: ante, kind: stage, difficulty: difficulty) }

    func makeCharmOffer() -> [Charm] {
        Array(Charm.allCases.filter { !charms.contains($0) }.shuffled().prefix(3))
    }
}
