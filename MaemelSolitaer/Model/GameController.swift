//
//  GameController.swift
//  MaemelSolitaer
//
//  Ties the rules engine, scoring and the journey together, and persists progress.
//

import SwiftUI
import Observation

nonisolated enum Screen: String, Codable, Sendable {
    case menu, chooseDifficulty, stageIntro, playing, stageComplete, charmPick, stageFailed, journeyComplete
}

nonisolated enum TableColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case forest, navy, slate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forest: String(localized: "Forest Green")
        case .navy: String(localized: "Warm Navy")
        case .slate: String(localized: "Dark Slate")
        }
    }
}

nonisolated struct GameSettings: Codable, Sendable {
    var drawThree = false
    var soundOn = true
    var tableColor: TableColor = .forest
    var leftHanded = false
}

private nonisolated struct SaveData: Codable {
    var run: RunState?
    var game: KlondikeGame
    var stageScore: Int
    var breakdown: [ScoreCategory: Int]
    var resumeScreen: Screen
    var bestScores: [Difficulty: Int]
}

/// A "+15" that floats over the card that earned the points while the score counts up.
struct ScorePop: Identifiable, Equatable {
    let id: Int
    let amount: Int
    /// The card to show it on; nil shows it in the middle of the table (e.g. board-cleared bonus).
    let cardID: Int?
    /// What each charm added to this gain.
    var bonuses: [CharmBonus] = []
}

private struct UndoSnapshot {
    let game: KlondikeGame
    let stageScore: Int
    let breakdown: [ScoreCategory: Int]
}

@Observable
final class GameController {
    private(set) var screen: Screen = .menu
    private(set) var run: RunState?
    private(set) var game = KlondikeGame()
    private(set) var stageScore = 0
    private(set) var breakdown: [ScoreCategory: Int] = [:]
    private(set) var bestScores: [Difficulty: Int] = [:]
    private(set) var settings = GameSettings()

    private(set) var activeHint: GameHint?
    private(set) var notice: String?
    private(set) var isStuck = false
    private(set) var isAutoCompleting = false
    private(set) var isRoundEnding = false
    /// True while a winnable deal is being prepared.
    private(set) var isDealing = false
    /// Incremented per card to drive a gentle "can't go there" shake.
    private(set) var shakes: [Int: Int] = [:]
    /// Cards that just moved; drawn on top so they glide over other cards.
    private(set) var recentlyMoved: Set<Int> = []
    /// Point gains currently floating over the table.
    private(set) var scorePops: [ScorePop] = []
    @ObservationIgnored private var nextPopID = 0
    /// Counts up whenever a charm adds points, so its icon in the charm panel can flash.
    private(set) var charmFlashes: [Charm: Int] = [:]
    /// The points each charm added most recently (shown beside the charm in the panel).
    private(set) var charmFlashAmounts: [Charm: Int] = [:]
    private(set) var dealToken = 0
    /// Set when a fresh deal should be animated by the table view.
    var pendingDealAnimation = false

    private var undoStack: [UndoSnapshot] = []
    @ObservationIgnored private var resumeScreen: Screen = .stageIntro
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private let sound = SoundManager()
    @ObservationIgnored private var dealTask: Task<Void, Never>?
    /// A winnable deal prepared in the background for the next round or retry.
    @ObservationIgnored private var prefetchedDeal: (config: DealConfig, task: Task<KlondikeGame, Never>)?

    private static let saveKey = "maemel.save.v2"
    private static let settingsKey = "maemel.settings.v1"
    private static let moveAnimation = Animation.spring(duration: 0.35, bounce: 0.12)

    init() {
        loadSettings()
        loadProgress()
        // Build the sounds in the background so the first card draw is instant.
        sound.prepare()
    }

    // MARK: - Derived state

    var canInteract: Bool { screen == .playing && !isAutoCompleting && !isRoundEnding && !isDealing }
    var canUndo: Bool { canInteract && !undoStack.isEmpty }
    var canAutoComplete: Bool { canInteract && game.canAutoComplete }
    var target: Int { run?.target ?? 0 }
    var targetReached: Bool { run != nil && stageScore >= target }

    var undoCost: Int {
        guard let run else { return 0 }
        return Scoring.undoCost(charms: run.charms, condition: run.condition)
    }

    var hintCost: Int {
        guard let run else { return 0 }
        return Scoring.hintCost(charms: run.charms, condition: run.condition)
    }

    var drawCountForStage: Int {
        (run?.condition == .drawThree || settings.drawThree || difficulty.alwaysDrawsThree) ? 3 : 1
    }

    var difficulty: Difficulty { run?.difficulty ?? .easy }

    private var currentDealConfig: DealConfig {
        DealConfig(difficulty: difficulty, drawCount: drawCountForStage, stage: run?.stage ?? .small)
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout GameSettings) -> Void) {
        change(&settings)
        sound.isEnabled = settings.soundOn
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    // MARK: - Journey flow

    func showDifficultyChoice() {
        screen = .chooseDifficulty
    }

    func startNewJourney(difficulty: Difficulty) {
        dealTask?.cancel()
        isDealing = false
        var newRun = RunState()
        newRun.difficulty = difficulty
        run = newRun
        undoStack = []
        game = KlondikeGame.empty(columns: difficulty.columnCount, decks: difficulty.deckCount, drawCount: drawCountForStage)
        stageScore = 0
        breakdown = [:]
        screen = .stageIntro
        prefetchDeal(for: currentDealConfig)
        save()
    }

    func continueJourney() {
        guard run != nil else { return }
        let hasDealtCards = !game.stock.isEmpty || !game.waste.isEmpty
            || game.tableau.contains { !$0.isEmpty } || game.foundations.contains { !$0.isEmpty }
        if resumeScreen == .playing && !hasDealtCards {
            screen = .stageIntro
        } else {
            screen = resumeScreen == .menu ? .stageIntro : resumeScreen
        }
        if screen == .stageIntro || screen == .stageFailed { prefetchDeal(for: currentDealConfig) }
    }

    func returnToMenu() {
        clearMessages()
        if screen != .menu && screen != .chooseDifficulty { resumeScreen = screen }
        screen = .menu
        save()
    }

    /// Deals fresh, guaranteed-winnable cards for the current round (also used for "Try Again").
    func dealStage() {
        guard run != nil, !isDealing else { return }
        clearMessages()
        let config = currentDealConfig
        // Show the empty table in the right shape while the deal is prepared.
        game = KlondikeGame.empty(columns: config.difficulty.columnCount, decks: config.difficulty.deckCount,
                                  drawCount: config.drawCount)
        stageScore = 0
        breakdown = [:]
        undoStack = []
        recentlyMoved = []
        isRoundEnding = false
        isStuck = false
        isDealing = true
        screen = .playing
        sound.play(.shuffle)

        dealTask = Task { [weak self] in
            guard let self else { return }
            let newGame = await self.takeDeal(for: config)
            guard !Task.isCancelled else { return }
            self.applyDeal(newGame, config: config)
        }
    }

    private func applyDeal(_ newGame: KlondikeGame, config: DealConfig) {
        game = newGame
        if run?.charms.contains(.headStart) == true {
            award([.charms: Scoring.headStartPoints], announce: false)
        }
        isStuck = game.findHint() == nil
        isDealing = false
        pendingDealAnimation = true
        dealToken += 1
        save()
        // Get the next deal ready for a retry or the next round.
        prefetchDeal(for: config)
    }

    private func takeDeal(for config: DealConfig) async -> KlondikeGame {
        if let prefetched = prefetchedDeal, prefetched.config == config {
            prefetchedDeal = nil
            return await prefetched.task.value
        }
        return await Task.detached(priority: .userInitiated) {
            DealGenerator.makeWinnableDeal(config)
        }.value
    }

    private func prefetchDeal(for config: DealConfig) {
        if let prefetched = prefetchedDeal {
            if prefetched.config == config { return }
            prefetched.task.cancel()
        }
        let task = Task.detached(priority: .utility) {
            DealGenerator.makeWinnableDeal(config)
        }
        prefetchedDeal = (config, task)
    }

    /// Ends the round: success if the target is reached, otherwise a gentle retry screen.
    func finishRound() {
        guard var run, screen == .playing, !isAutoCompleting else { return }
        clearMessages()
        isRoundEnding = false
        if stageScore >= run.target {
            run.totalScore += stageScore
            run.roundsCleared += 1
            // Clearing the whole board earns a second charm.
            run.boardWasCleared = game.isWon
            run.charmPicksRemaining = game.isWon ? RunState.charmPicksForClearedBoard : 1
            bestScores[run.difficulty] = max(bestScores[run.difficulty] ?? 0, run.totalScore)
            self.run = run
            screen = .stageComplete
            sound.play(.success)
        } else {
            screen = .stageFailed
        }
        save()
    }

    func showCharmChoices() {
        guard var run else { return }
        run.offeredCharms = run.makeCharmOffer()
        self.run = run
        if run.offeredCharms.isEmpty {
            advanceToNextStage()
        } else {
            screen = .charmPick
            save()
        }
    }

    /// Adds a charm. Requires a free slot — remove a charm first when all 9 are taken.
    func chooseCharm(_ charm: Charm) {
        guard var run, run.charms.count < RunState.maxCharms else { return }
        if !run.charms.contains(charm) { run.charms.append(charm) }
        self.run = run
        sound.play(.foundation)
        finishCharmPick()
    }

    /// Deletes a charm from the journey, freeing its slot.
    func removeCharm(_ charm: Charm) {
        guard var run, run.charms.contains(charm) else { return }
        run.charms.removeAll { $0 == charm }
        self.run = run
        sound.play(.place)
        save()
    }

    /// Puts back a charm that was just removed, if there is still room.
    func restoreCharm(_ charm: Charm) {
        guard var run, !run.charms.contains(charm), run.charms.count < RunState.maxCharms else { return }
        run.charms.append(charm)
        self.run = run
        sound.play(.foundation)
        save()
    }

    /// Passes on the current charm choice.
    func skipCharm() {
        finishCharmPick()
    }

    /// Offers the next charm choice if one was earned, otherwise moves on to the next round.
    private func finishCharmPick() {
        guard var run else { return }
        run.charmPicksRemaining -= 1
        if run.charmPicksRemaining > 0 {
            run.offeredCharms = run.makeCharmOffer()
            self.run = run
            if !run.offeredCharms.isEmpty {
                save()
                return
            }
        }
        run.charmPicksRemaining = 0
        self.run = run
        advanceToNextStage()
    }

    func continueEndless() {
        screen = .stageIntro
        prefetchDeal(for: currentDealConfig)
        save()
    }

    private func advanceToNextStage() {
        guard var run else { return }
        let finishedBoss = run.stage == .boss
        if finishedBoss {
            run.ante += 1
            run.stage = .small
        } else {
            run.stage = StageKind(rawValue: run.stage.rawValue + 1) ?? .boss
        }
        run.offeredCharms = []
        run.condition = StageCondition.random(for: run.stage, ante: run.ante,
                                              playerDrawsThree: settings.drawThree || run.difficulty.alwaysDrawsThree)

        let completedJourney = finishedBoss && run.ante > RunState.chapterCount && !run.hasCompletedJourney
        if completedJourney { run.hasCompletedJourney = true }
        self.run = run
        screen = completedJourney ? .journeyComplete : .stageIntro
        if !completedJourney { prefetchDeal(for: currentDealConfig) }
        save()
    }

    // MARK: - Playing

    func tapCard(at pile: PileID, index: Int) {
        guard canInteract else { return }
        if pile == .stock {
            drawFromStock()
            return
        }
        guard let destination = game.bestDestination(from: pile, at: index) else {
            rejectTap(pile: pile, index: index)
            return
        }
        performMove(from: pile, index: index, to: destination)
    }

    @discardableResult
    func performMove(from source: PileID, index: Int, to destination: PileID) -> Bool {
        guard canInteract else { return false }
        var next = game
        guard let events = next.move(from: source, at: index, to: destination) else {
            playRejectSound()
            return false
        }
        let moved = game.cards(in: source)[index...].map(\.id)
        pushUndo()
        withAnimation(Self.moveAnimation) {
            game = next
            recentlyMoved = Set(moved)
        }
        handle(events, anchorCardID: moved.first)
        return true
    }

    func drawFromStock() {
        guard canInteract else { return }
        var next = game
        guard let events = next.dealFromStock() else { return }
        pushUndo()
        withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
            game = next
            recentlyMoved = Set(next.waste.suffix(next.drawCount).map(\.id))
        }
        handle(events)
    }

    func undo() {
        guard canUndo, let snapshot = undoStack.popLast() else { return }
        clearMessages()
        withAnimation(Self.moveAnimation) {
            game = snapshot.game
            stageScore = snapshot.stageScore
            breakdown = snapshot.breakdown
            recentlyMoved = []
        }
        let cost = undoCost
        if cost > 0 { award([.penalties: -cost], announce: false) }
        isStuck = !game.isWon && game.findHint() == nil
        sound.play(.place)
        save()
    }

    func showHint() {
        guard canInteract, activeHint == nil else { return }
        guard let hint = game.findHint() else {
            isStuck = true
            sound.play(.invalid)
            return
        }
        let cost = hintCost
        if cost > 0 { award([.penalties: -cost], announce: false) }
        withAnimation(.easeInOut(duration: 0.25)) { activeHint = hint }
        sound.play(.hint)
        scheduleMessageDismissal(after: .seconds(6))
    }

    func clearHint() {
        guard activeHint != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) { activeHint = nil }
    }

    /// Plays the remaining cards up to the foundations, one gentle step at a time.
    func autoComplete() {
        guard canAutoComplete else { return }
        clearMessages()
        pushUndo()
        isAutoCompleting = true
        Task { [weak self] in
            guard let self else { return }
            var drawsWithoutProgress = 0
            while !self.game.isWon, let step = self.game.nextAutoCompleteStep() {
                try? await Task.sleep(for: .milliseconds(170))
                var next = self.game
                let events: MoveEvents?
                let anchor = self.game.cards(in: step.from).indices.contains(step.index)
                    ? self.game.cards(in: step.from)[step.index].id : nil
                if let destination = step.to {
                    events = next.move(from: step.from, at: step.index, to: destination)
                    drawsWithoutProgress = 0
                } else {
                    events = next.dealFromStock()
                    drawsWithoutProgress += 1
                }
                guard let events, drawsWithoutProgress <= 60 else { break }
                withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                    self.game = next
                    self.recentlyMoved = []
                }
                self.handle(events, anchorCardID: anchor)
            }
            self.isAutoCompleting = false
        }
    }

    func playRejectSound() { sound.play(.invalid) }
    func playTick() { sound.play(.tick) }

    // MARK: - Internals

    private func handle(_ events: MoveEvents, anchorCardID: Int? = nil) {
        guard let run else { return }
        award(Scoring.points(for: events, charms: run.charms, condition: run.condition),
              anchorCardID: anchorCardID,
              charmBonuses: Scoring.charmBonuses(for: events, charms: run.charms))

        if events.reachedFoundation {
            sound.play(.foundation)
        } else if events.drewCards || events.recycledStock {
            sound.play(.flip)
        } else {
            sound.play(.place)
        }
        if events.revealedCards > 0 {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(160))
                self?.sound.play(.flip)
            }
        }

        if activeHint != nil { clearHint() }

        if game.isWon {
            handleBoardCleared()
        } else {
            isStuck = game.findHint() == nil
        }
        save()
    }

    private func handleBoardCleared() {
        guard let run, !isRoundEnding else { return }
        isRoundEnding = true
        isStuck = false
        award(Scoring.boardClearAward(moveCount: game.moveCount, charms: run.charms, condition: run.condition),
              charmBonuses: Scoring.boardClearCharmBonuses(charms: run.charms))
        Task { [weak self] in
            // Let the bonus count up on screen before the celebration.
            try? await Task.sleep(for: .seconds(1.6))
            // Wait for auto-complete to wind down before showing the celebration.
            while self?.isAutoCompleting == true {
                try? await Task.sleep(for: .milliseconds(100))
            }
            self?.isRoundEnding = false
            self?.finishRound()
        }
    }

    /// How long the score counter takes to count up by `amount`:
    /// one tenth of a second per point, but never longer than one second.
    static func countUpDuration(for amount: Int) -> Double {
        min(1.0, Double(max(amount, 1)) * 0.1)
    }

    private func award(_ points: [ScoreCategory: Int], announce: Bool = true, anchorCardID: Int? = nil,
                       charmBonuses: [CharmBonus] = []) {
        let wasReached = targetReached
        var total = 0
        for (category, value) in points where value != 0 {
            breakdown[category, default: 0] += value
            total += value
        }
        stageScore = max(0, stageScore + total)
        if total > 0 && announce {
            showScorePop(total, at: anchorCardID, bonuses: charmBonuses)
            for bonus in charmBonuses {
                charmFlashAmounts[bonus.charm] = bonus.amount
                charmFlashes[bonus.charm, default: 0] += 1
            }
        }
        if !wasReached && targetReached && screen == .playing && !game.isWon {
            showNotice(String(localized: "Target reached! Finish now for 1 charm — or clear the whole board to choose 2 charms."))
        }
    }

    private func showScorePop(_ amount: Int, at cardID: Int?, bonuses: [CharmBonus]) {
        nextPopID += 1
        let pop = ScorePop(id: nextPopID, amount: amount, cardID: cardID, bonuses: bonuses)
        scorePops.append(pop)
        // Stays while the counter counts up, then fades (the view handles the fade).
        let lifetime = Self.countUpDuration(for: amount) + 0.5
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            self?.scorePops.removeAll { $0.id == pop.id }
        }
    }

    private func pushUndo() {
        undoStack.append(UndoSnapshot(game: game, stageScore: stageScore, breakdown: breakdown))
        if undoStack.count > 300 { undoStack.removeFirst() }
    }

    private func rejectTap(pile: PileID, index: Int) {
        let cards = game.cards(in: pile)
        guard cards.indices.contains(index) else { return }
        let id = cards[index].id
        withAnimation(.linear(duration: 0.4)) {
            shakes[id, default: 0] += 1
        }
        playRejectSound()
    }

    private func showNotice(_ text: String) {
        withAnimation(.easeInOut(duration: 0.25)) { notice = text }
        scheduleMessageDismissal(after: .seconds(5))
    }

    private func scheduleMessageDismissal(after delay: Duration) {
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.activeHint = nil
                self?.notice = nil
            }
        }
    }

    private func clearMessages() {
        messageTask?.cancel()
        activeHint = nil
        notice = nil
    }

    // MARK: - Persistence

    private func save() {
        let data = SaveData(
            run: run,
            game: game,
            stageScore: stageScore,
            breakdown: breakdown,
            resumeScreen: screen == .menu ? resumeScreen : screen,
            bestScores: bestScores
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let saved = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        run = saved.run
        game = saved.game
        stageScore = saved.stageScore
        breakdown = saved.breakdown
        bestScores = saved.bestScores
        resumeScreen = saved.resumeScreen
        isStuck = !game.isWon && game.findHint() == nil
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(GameSettings.self, from: data) {
            settings = saved
        }
        sound.isEnabled = settings.soundOn
    }
}
