//
//  JourneyScreens.swift
//  MaemelSolitaer
//
//  Main menu and the screens between rounds. Large text, one clear action per screen.
//

import SwiftUI

// MARK: - Main menu

struct MainMenuView: View {
    @Environment(GameController.self) private var controller
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var confirmNewJourney = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let compact = sizeClass == .compact
        ScrollView {
            VStack(spacing: compact ? 18 : 30) {
                FannedAces()
                    .scaleEffect(compact ? 0.75 : 1)
                    .frame(height: compact ? 150 : 190)
                    .padding(.top, compact ? 10 : 30)

                VStack(spacing: 10) {
                    Text(verbatim: "Mämel Solitaire")
                        .font(.system(size: 64, weight: .heavy, design: .serif))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text("A relaxing journey through classic Klondike")
                        .font(Theme.rounded(.title2))
                        .opacity(0.85)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 18) {
                    if let run = controller.run {
                        Button {
                            controller.continueJourney()
                        } label: {
                            VStack(spacing: 4) {
                                Text("Continue Journey")
                                Text("\(run.difficulty.title) · Chapter \(run.ante) · \(run.stage.title)")
                                    .font(Theme.rounded(.title3, weight: .medium))
                            }
                        }
                        .buttonStyle(BigButtonStyle())
                    }

                    Button("New Journey") {
                        if controller.run != nil {
                            confirmNewJourney = true
                        } else {
                            controller.showDifficultyChoice()
                        }
                    }
                    .buttonStyle(BigButtonStyle(kind: controller.run == nil ? .primary : .secondary))

                    HStack(spacing: 18) {
                        Button {
                            showHelp = true
                        } label: {
                            Label("How to Play", systemImage: "questionmark.circle.fill")
                                .labelStyle(AdaptiveLabelStyle())
                        }
                        .buttonStyle(BigButtonStyle(kind: .secondary))

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .labelStyle(AdaptiveLabelStyle())
                        }
                        .buttonStyle(BigButtonStyle(kind: .secondary))
                    }
                }
                .frame(maxWidth: 600)

                let best = Difficulty.allCases.compactMap { level in
                    controller.bestScores[level].map { (level, $0) }
                }
                if !best.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(best, id: \.0) { level, score in
                            Label("Best \(level.title) journey: \(score.formatted())", systemImage: "trophy.fill")
                        }
                    }
                    .font(Theme.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                }
            }
            .padding(compact ? 18 : 40)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(.white)
        .alert("Start a new journey?", isPresented: $confirmNewJourney) {
            Button("Start New Journey", role: .destructive) { controller.showDifficultyChoice() }
            Button("Keep My Journey", role: .cancel) {}
        } message: {
            Text("Your current journey and charms will be replaced.")
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .environment(controller)
                .presentationBackground(Theme.sheetBackground)
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack { HowToPlayView() }
                .presentationBackground(Theme.sheetBackground)
        }
    }
}

/// Shows the icon with the title, but title only on narrow (phone) screens, where two buttons share a row.
private struct AdaptiveLabelStyle: LabelStyle {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func makeBody(configuration: Configuration) -> some View {
        if sizeClass == .compact {
            configuration.title
        } else {
            Label { configuration.title } icon: { configuration.icon }
        }
    }
}

/// Four aces fanned out as a friendly title decoration.
private struct FannedAces: View {
    var body: some View {
        let size = CGSize(width: 110, height: 154)
        ZStack {
            ForEach(Array(Suit.allCases.enumerated()), id: \.offset) { index, suit in
                let angle = Double(index) * 12 - 18
                CardView(card: Card(suit: suit, rank: 1, isFaceUp: true), size: size)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(x: CGFloat(index) * 34 - 51)
            }
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }
}

// MARK: - Difficulty

extension Difficulty {
    var tint: Color {
        switch self {
        case .easy: Theme.success
        case .medium: Color(red: 1.0, green: 0.68, blue: 0.35)
        case .hard: Color(red: 1.0, green: 0.48, blue: 0.48)
        }
    }
}

struct DifficultyPickerView: View {
    @Environment(GameController.self) private var controller
    @State private var selected: Difficulty = .easy

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("Choose Your Challenge")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Same classic rules at every level. Every deal can be won.")
                        .font(Theme.rounded(.title2))
                        .opacity(0.85)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    ForEach(Difficulty.allCases) { level in
                        Button {
                            withAnimation(.spring(duration: 0.3)) { selected = level }
                            controller.playTick()
                        } label: {
                            DifficultyCard(difficulty: level, isSelected: selected == level)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 720)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button("Back") {
                    controller.returnToMenu()
                }
                .buttonStyle(BigButtonStyle(kind: .secondary))
                .frame(maxWidth: 260)

                Button {
                    controller.startNewJourney(difficulty: selected)
                } label: {
                    Label("Start \(selected.title) Journey", systemImage: "play.fill")
                }
                .buttonStyle(BigButtonStyle())
                .frame(maxWidth: 480)
            }
        }
        .foregroundStyle(.white)
    }
}

/// Keeps a screen's main buttons pinned to the bottom edge, always visible without scrolling.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 18) {
            content
        }
        .frame(maxWidth: 900)
        .padding(.horizontal, 30)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.35).ignoresSafeArea(edges: .bottom))
    }
}

private struct DifficultyCard: View {
    let difficulty: Difficulty
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        HStack(spacing: 20) {
            Image(systemName: difficulty.symbolName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(difficulty.tint)
                .frame(width: 80, height: 80)
                .background(Circle().fill(difficulty.tint.opacity(0.2)))
            VStack(alignment: .leading, spacing: 6) {
                Text(difficulty.title)
                    .font(Theme.rounded(.largeTitle, weight: .heavy))
                Text(difficulty.detail)
                    .font(Theme.rounded(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                Text(difficulty.tableSummary)
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(difficulty.tint)
            }
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.gold : .white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(shape.fill(isSelected ? difficulty.tint.opacity(0.18) : Color.black.opacity(0.32)))
        .overlay(shape.strokeBorder(isSelected ? Theme.gold : Color.white.opacity(0.25), lineWidth: isSelected ? 5 : 2))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Round intro

struct StageIntroView: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        if let run = controller.run {
            ScrollView {
                VStack(spacing: 26) {
                    StageProgressDots(current: run.stage)

                    VStack(spacing: 6) {
                        Label("Chapter \(run.ante) · \(run.difficulty.title)", systemImage: run.difficulty.symbolName)
                            .font(Theme.rounded(.title2, weight: .semibold))
                            .opacity(0.85)
                        Label(run.stage.title, systemImage: run.stage.symbolName)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 2) {
                        Text("Target Score")
                            .font(Theme.rounded(.title2, weight: .medium))
                        Text(run.target, format: .number)
                            .font(.system(size: 84, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.gold)
                    }

                    ConditionCard(condition: run.condition)

                    Label(controller.drawCountForStage == 3 ? String(localized: "Turn over 3 deck cards at a time") : String(localized: "Turn over 1 deck card at a time"),
                          systemImage: "rectangle.stack.fill")
                        .font(Theme.rounded(.title3, weight: .medium))
                        .opacity(0.9)

                    BoardBonusBadge(text: String(localized: "Clear the whole board to choose 2 charms"))

                    if !run.charms.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your Charms  \(run.charms.count) of \(RunState.maxCharms)")
                                .font(Theme.rounded(.title2, weight: .bold))
                            ForEach(run.charms) { charm in
                                CharmRow(charm: charm)
                            }
                        }
                        .padding(20)
                        .panelBackground()
                    }
                }
                .frame(maxWidth: 760)
                .padding(40)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                BottomActionBar {
                    Button("Main Menu") {
                        controller.returnToMenu()
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))
                    .frame(maxWidth: 260)

                    Button {
                        controller.dealStage()
                    } label: {
                        Label("Deal the Cards", systemImage: "play.fill")
                    }
                    .buttonStyle(BigButtonStyle())
                    .frame(maxWidth: 480)
                }
            }
            .foregroundStyle(.white)
        }
    }
}

/// Golden pill that advertises the bonus charm for clearing the board.
struct BoardBonusBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(Theme.rounded(.title3, weight: .bold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.gold))
    }
}

// MARK: - Round cleared

struct StageCompleteView: View {
    @Environment(GameController.self) private var controller
    @State private var shownRows = 0
    @State private var showTotals = false

    var body: some View {
        let rows = ScoreCategory.allCases.compactMap { category -> (ScoreCategory, Int)? in
            guard let value = controller.breakdown[category], value != 0 else { return nil }
            return (category, value)
        }
        ZStack {
            // Opaque, so the finished board (and its score) never ghosts behind the title.
            FeltBackground(color: controller.settings.tableColor)
            Color.black.opacity(0.35).ignoresSafeArea()
            CascadingCardsView()

            if let run = controller.run {
                ScrollView {
                    VStack(spacing: 22) {
                        Text(run.stage == .boss ? String(localized: "Chapter Complete!") : String(localized: "Round Cleared!"))
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.gold)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.4), radius: 6)

                        VStack(spacing: 12) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                TallyRow(title: row.0.title, systemImage: row.0.symbolName, value: row.1)
                                    .opacity(index < shownRows ? 1 : 0)
                                    .offset(y: index < shownRows ? 0 : 14)
                            }

                            Divider().overlay(Color.white.opacity(0.4))

                            Group {
                                totalRow(String(localized: "Round score"), value: controller.stageScore, highlight: true)
                                totalRow(String(localized: "Target"), value: run.target, highlight: false)
                                totalRow(String(localized: "Journey total"), value: run.totalScore, highlight: false)
                            }
                            .opacity(showTotals ? 1 : 0)
                        }
                        .padding(24)
                        .frame(maxWidth: 620)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.6)))

                        if run.boardWasCleared {
                            BoardBonusBadge(text: String(localized: "Board cleared — you may choose 2 charms!"))
                        }

                        Button {
                            controller.showCharmChoices()
                        } label: {
                            Label(run.charmPicksRemaining > 1 ? String(localized: "Choose 2 Charms") : String(localized: "Choose a Charm"), systemImage: "sparkles")
                        }
                        .buttonStyle(BigButtonStyle())
                        .frame(maxWidth: 460)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.white)
            }
        }
        .task {
            // Reveal the tally one line at a time.
            for index in 0..<rows.count {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.spring(duration: 0.4)) { shownRows = index + 1 }
                controller.playTick()
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.5)) { showTotals = true }
        }
    }

    private func totalRow(_ title: String, value: Int, highlight: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value, format: .number)
                .foregroundStyle(highlight ? Theme.gold : .white)
        }
        .font(Theme.rounded(highlight ? .title : .title2, weight: .bold))
    }
}

private struct TallyRow: View {
    let title: String
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 36)
                .foregroundStyle(Theme.gold)
            Text(title)
            Spacer()
            Text(value > 0 ? "+\(value.formatted())" : value.formatted())
                .foregroundStyle(value > 0 ? Theme.success : Color(red: 1.0, green: 0.7, blue: 0.6))
        }
        .font(Theme.rounded(.title2, weight: .semibold))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Round not cleared

struct StageFailedView: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            if let run = controller.run {
                VStack(spacing: 24) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.success)
                    Text("Not quite this time")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("You scored \(controller.stageScore.formatted()) points. The target was \(run.target.formatted()).")
                        .font(Theme.rounded(.title2))
                        .multilineTextAlignment(.center)
                    Text("Every deal is different — your charms are kept. Try a fresh deal!")
                        .font(Theme.rounded(.title3))
                        .opacity(0.85)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 16) {
                        Button {
                            controller.dealStage()
                        } label: {
                            Label("Try Again with New Cards", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(BigButtonStyle())

                        Button("Main Menu") {
                            controller.returnToMenu()
                        }
                        .buttonStyle(BigButtonStyle(kind: .secondary))
                    }
                    .frame(maxWidth: 480)
                }
                .padding(40)
                .frame(maxWidth: 700)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.sheetBackground.opacity(0.95)))
                .padding(30)
                .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Charm picker

struct CharmPickerView: View {
    @Environment(GameController.self) private var controller
    /// The new charm the player wants.
    @State private var selected: Charm?
    /// The owned charm tapped in the grid; shows its description and a Remove button.
    @State private var focusedSlot: Charm?
    /// The charm removed most recently on this screen, so a mis-tap can be put right.
    @State private var recentlyRemoved: Charm?

    private var owned: [Charm] { controller.run?.charms ?? [] }
    private var isFull: Bool { owned.count >= RunState.maxCharms }
    private var picksRemaining: Int { controller.run?.charmPicksRemaining ?? 1 }
    private var isBonusRound: Bool { controller.run?.boardWasCleared ?? false }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    if isBonusRound {
                        BoardBonusBadge(text: picksRemaining > 1
                                        ? String(localized: "Board cleared! This is charm 1 of 2.")
                                        : String(localized: "Bonus for clearing the board: charm 2 of 2."))
                    }
                    Text("Choose a Charm")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                    Text(isFull
                         ? String(localized: "All 9 charm slots are full. Tap one of your charms and remove it to make room.")
                         : String(localized: "Your charm helps you in every round for the rest of the journey."))
                        .font(Theme.rounded(.title2))
                        .opacity(0.9)
                        .multilineTextAlignment(.center)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 30) {
                        offers.frame(width: 520)
                        slotGrid.frame(width: 480)
                    }
                    VStack(spacing: 26) {
                        offers.frame(maxWidth: 620)
                        slotGrid.frame(maxWidth: 520)
                    }
                }

            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button(picksRemaining > 1 ? String(localized: "Skip This Charm") : String(localized: "Keep My Charms")) {
                    controller.skipCharm()
                }
                .buttonStyle(BigButtonStyle(kind: .secondary))
                .frame(maxWidth: 300)

                Button(action: confirm) {
                    Text(confirmTitle)
                }
                .buttonStyle(BigButtonStyle())
                .disabled(!canConfirm)
                .frame(maxWidth: 520)
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: Offered charms

    private var offers: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Charms")
                .font(Theme.rounded(.title, weight: .bold))
            ForEach(controller.run?.offeredCharms ?? []) { charm in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selected = charm }
                    controller.playTick()
                } label: {
                    CharmOfferRow(charm: charm, isSelected: selected == charm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 3 x 3 slots

    private var slotGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Charms  \(owned.count) of \(RunState.maxCharms)")
                .font(Theme.rounded(.title, weight: .bold))
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            slot(at: row * 3 + column)
                        }
                    }
                }
            }
            if let focusedSlot {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(focusedSlot.title): \(focusedSlot.detail)")
                        .font(Theme.rounded(.title3))
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        remove(focusedSlot)
                    } label: {
                        Label("Remove “\(focusedSlot.title)”", systemImage: "trash.fill")
                            .foregroundStyle(Self.removeTint)
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.1)))
            }
            if let recentlyRemoved, !owned.contains(recentlyRemoved), !isFull {
                Button {
                    controller.restoreCharm(recentlyRemoved)
                    self.recentlyRemoved = nil
                } label: {
                    Label("Put “\(recentlyRemoved.title)” back", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(BigButtonStyle(kind: .secondary))
            }
        }
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        if index < owned.count {
            let charm = owned[index]
            let isFocused = focusedSlot == charm
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    focusedSlot = isFocused ? nil : charm
                }
                controller.playTick()
            } label: {
                CharmSlot(charm: charm, isFocused: isFocused)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                // A real delete button, separate from the slot itself.
                if isFocused {
                    Button {
                        remove(charm)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white, Self.removeTint)
                            .frame(width: 56, height: 56)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 18, y: -18)
                    .accessibilityLabel("Remove \(charm.title)")
                }
            }
            .zIndex(isFocused ? 1 : 0)
        } else {
            EmptyCharmSlot()
        }
    }

    // MARK: Confirmation

    static let removeTint = Color(red: 1.0, green: 0.45, blue: 0.45)

    private var canConfirm: Bool { selected != nil && !isFull }

    private var confirmTitle: String {
        if isFull { return String(localized: "Remove a charm to make room") }
        guard let selected else { return String(localized: "Tap a new charm to choose it") }
        return String(localized: "Take “\(selected.title)”")
    }

    private func confirm() {
        guard let selected, !isFull else { return }
        controller.chooseCharm(selected)
    }

    private func remove(_ charm: Charm) {
        withAnimation(.spring(duration: 0.35)) {
            controller.removeCharm(charm)
            focusedSlot = nil
            recentlyRemoved = charm
        }
    }
}

private struct CharmOfferRow: View {
    let charm: Charm
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 18) {
            CharmIcon(charm: charm, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(charm.title)
                    .font(Theme.rounded(.title, weight: .bold))
                Text(charm.detail)
                    .font(Theme.rounded(.title3))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.gold : .white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(shape.fill(isSelected ? charm.tint.opacity(0.22) : Color.black.opacity(0.32)))
        .overlay(shape.strokeBorder(isSelected ? Theme.gold : Color.white.opacity(0.25), lineWidth: isSelected ? 5 : 2))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// One filled slot of the 3 x 3 charm grid.
private struct CharmSlot: View {
    let charm: Charm
    let isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 8) {
            CharmIcon(charm: charm, size: 52)
            Text(charm.title)
                .font(Theme.rounded(.headline, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(width: 150, height: 130)
        .background(shape.fill(isFocused ? Theme.gold.opacity(0.15) : Color.black.opacity(0.32)))
        .overlay(shape.strokeBorder(isFocused ? Theme.gold : Color.white.opacity(0.25), lineWidth: isFocused ? 4 : 2))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows what this charm does and lets you remove it")
        .accessibilityAddTraits(.isButton)
    }
}

private struct EmptyCharmSlot: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Text("Empty")
            .font(Theme.rounded(.headline))
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 150, height: 130)
            .background(shape.fill(Color.black.opacity(0.15)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
            .accessibilityLabel("Empty charm slot")
    }
}

// MARK: - Journey complete

struct JourneyCompleteView: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        ZStack {
            CascadingCardsView()
            VStack(spacing: 26) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(Theme.gold)
                Text("Journey Complete!")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("You cleared all \(RunState.chapterCount) chapters. Wonderful playing!")
                    .font(Theme.rounded(.title2))
                    .multilineTextAlignment(.center)
                if let run = controller.run {
                    Text("Total score: \(run.totalScore.formatted())")
                        .font(Theme.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                VStack(spacing: 16) {
                    Button("Keep Playing") { controller.continueEndless() }
                        .buttonStyle(BigButtonStyle())
                    Button("Main Menu") { controller.returnToMenu() }
                        .buttonStyle(BigButtonStyle(kind: .secondary))
                }
                .frame(maxWidth: 460)
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.black.opacity(0.55)))
            .padding(30)
            .foregroundStyle(.white)
        }
    }
}
