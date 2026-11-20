//
//  GameController.swift
//  MaemelSolitaer
//
//  Ties the rules engine, scoring and the journey together, and persists progress.
//

import SwiftUI
import Observation

nonisolated enum Screen: String, Codable, Sendable {
    case menu, stageIntro, playing, stageComplete, charmPick, stageFailed, journeyComplete
}

nonisolated enum TableColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case forest, navy, slate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forest: "Forest Green"
        case .navy: "Warm Navy"
        case .slate: "Dark Slate"
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
    var bestScore: Int
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
    private(set) var bestScore = 0
    private(set) var settings = GameSettings()

    private(set) var activeHint: GameHint?
    private(set) var notice: String?
    private(set) var isStuck = false
    private(set) var isAutoCompleting = false
    private(set) var isRoundEnding = false
    /// Incremented per card to drive a gentle "can't go there" shake.
    private(set) var shakes: [Int: Int] = [:]
    /// Cards that just moved; drawn on top so they glide over other cards.
    private(set) var recentlyMoved: Set<Int> = []
    private(set) var lastGain = 0
    private(set) var gainToken = 0
    private(set) var dealToken = 0
    /// Set when a fresh deal should be animated by the table view.
    var pendingDealAnimation = false

    private var undoStack: [UndoSnapshot] = []
    @ObservationIgnored private var resumeScreen: Screen = .stageIntro
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private let sound = SoundManager()

    private static let saveKey = "maemel.save.v1"
    private static let settingsKey = "maemel.settings.v1"
    private static let moveAnimation = Animation.spring(duration: 0.35, bounce: 0.12)

    init() {
        loadSettings()
        loadProgress()
    }

    // MARK: - Derived state

    var canInteract: Bool { screen == .playing && !isAutoCompleting && !isRoundEnding }
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
        (run?.condition == .drawThree || settings.drawThree) ? 3 : 1
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

    func startNewJourney() {
        run = RunState()
        undoStack = []
        game = KlondikeGame()
        stageScore = 0
        breakdown = [:]
        screen = .stageIntro
        save()
    }

    func continueJourney() {
        guard run != nil else { return }
        if resumeScreen == .playing && game.cards(in: .stock).isEmpty && game.tableau.allSatisfy(\.isEmpty) {
            screen = .stageIntro
        } else {
            screen = resumeScreen == .menu ? .stageIntro : resumeScreen
        }
    }

    func returnToMenu() {
        clearMessages()
        if screen != .menu { resumeScreen = screen }
        screen = .menu
        save()
    }

    /// Deals fresh cards for the current round (also used for "Try Again").
    func dealStage() {
        guard let run else { return }
        clearMessages()
        game = KlondikeGame.deal(drawCount: drawCountForStage)
        stageScore = 0
        breakdown = [:]
        if run.charms.contains(.headStart) {
            award([.charms: Scoring.headStartPoints], announce: false)
        }
        undoStack = []
        recentlyMoved = []
        isRoundEnding = false
        isStuck = game.findHint() == nil
        pendingDealAnimation = true
        dealToken += 1
        screen = .playing
        sound.play(.shuffle)
        save()
    }

    /// Ends the round: success if the target is reached, otherwise a gentle retry screen.
    func finishRound() {
        guard var run, screen == .playing, !isAutoCompleting else { return }
        clearMessages()
        isRoundEnding = false
        if stageScore >= run.target {
            run.totalScore += stageScore
            run.roundsCleared += 1
            bestScore = max(bestScore, run.totalScore)
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

    func chooseCharm(_ charm: Charm) {
        guard var run else { return }
        if !run.charms.contains(charm) { run.charms.append(charm) }
        self.run = run
        sound.play(.foundation)
        advanceToNextStage()
    }

    func continueEndless() {
        screen = .stageIntro
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
        run.condition = StageCondition.random(for: run.stage, ante: run.ante, playerDrawsThree: settings.drawThree)

        let completedJourney = finishedBoss && run.ante > RunState.chapterCount && !run.hasCompletedJourney
        if completedJourney { run.hasCompletedJourney = true }
        self.run = run
        screen = completedJourney ? .journeyComplete : .stageIntro
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
        let movedIDs = Set(game.cards(in: source)[index...].map(\.id))
        pushUndo()
        withAnimation(Self.moveAnimation) {
            game = next
            recentlyMoved = movedIDs
        }
        handle(events)
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
                self.handle(events)
            }
            self.isAutoCompleting = false
        }
    }

    func playRejectSound() { sound.play(.invalid) }
    func playTick() { sound.play(.tick) }

    // MARK: - Internals

    private func handle(_ events: MoveEvents) {
        guard let run else { return }
        award(Scoring.points(for: events, charms: run.charms, condition: run.condition))

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
        award(Scoring.boardClearAward(moveCount: game.moveCount, charms: run.charms, condition: run.condition))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            // Wait for auto-complete to wind down before showing the celebration.
            while self?.isAutoCompleting == true {
                try? await Task.sleep(for: .milliseconds(100))
            }
            self?.isRoundEnding = false
            self?.finishRound()
        }
    }

    private func award(_ points: [ScoreCategory: Int], announce: Bool = true) {
        let wasReached = targetReached
        var total = 0
        for (category, value) in points where value != 0 {
            breakdown[category, default: 0] += value
            total += value
        }
        withAnimation(.spring(duration: 0.4)) {
            stageScore = max(0, stageScore + total)
        }
        if total > 0 && announce {
            lastGain = total
            gainToken += 1
        }
        if !wasReached && targetReached && screen == .playing && !game.isWon {
            showNotice("Target reached! Tap “Finish Round”, or keep playing for more points.")
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
            bestScore: bestScore
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
        bestScore = saved.bestScore
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
