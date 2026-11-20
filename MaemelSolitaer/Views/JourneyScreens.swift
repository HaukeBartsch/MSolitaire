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

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                FannedAces()
                    .padding(.top, 30)

                VStack(spacing: 10) {
                    Text("Maemel Solitaire")
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
                                Text("Chapter \(run.ante) · \(run.stage.title)")
                                    .font(Theme.rounded(.title3, weight: .medium))
                            }
                        }
                        .buttonStyle(BigButtonStyle())
                    }

                    Button("New Journey") {
                        if controller.run != nil {
                            confirmNewJourney = true
                        } else {
                            controller.startNewJourney()
                        }
                    }
                    .buttonStyle(BigButtonStyle(kind: controller.run == nil ? .primary : .secondary))

                    HStack(spacing: 18) {
                        Button {
                            showHelp = true
                        } label: {
                            Label("How to Play", systemImage: "questionmark.circle.fill")
                        }
                        .buttonStyle(BigButtonStyle(kind: .secondary))

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(BigButtonStyle(kind: .secondary))
                    }
                }
                .frame(maxWidth: 600)

                if controller.bestScore > 0 {
                    Label("Best journey score: \(controller.bestScore.formatted())", systemImage: "trophy.fill")
                        .font(Theme.rounded(.title3, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .alert("Start a new journey?", isPresented: $confirmNewJourney) {
            Button("Start New Journey", role: .destructive) { controller.startNewJourney() }
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

// MARK: - Round intro

struct StageIntroView: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        if let run = controller.run {
            ScrollView {
                VStack(spacing: 26) {
                    StageProgressDots(current: run.stage)

                    VStack(spacing: 6) {
                        Text("Chapter \(run.ante)")
                            .font(Theme.rounded(.title2, weight: .semibold))
                            .opacity(0.8)
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

                    Label(controller.drawCountForStage == 3 ? "Turn over 3 deck cards at a time" : "Turn over 1 deck card at a time",
                          systemImage: "rectangle.stack.fill")
                        .font(Theme.rounded(.title3, weight: .medium))
                        .opacity(0.9)

                    if !run.charms.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your Charms")
                                .font(Theme.rounded(.title2, weight: .bold))
                            ForEach(run.charms) { charm in
                                CharmRow(charm: charm)
                            }
                        }
                        .padding(20)
                        .panelBackground()
                    }

                    Button {
                        controller.dealStage()
                    } label: {
                        Label("Deal the Cards", systemImage: "play.fill")
                    }
                    .buttonStyle(BigButtonStyle())
                    .frame(maxWidth: 460)

                    Button("Main Menu") {
                        controller.returnToMenu()
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))
                    .frame(maxWidth: 300)
                }
                .frame(maxWidth: 760)
                .padding(40)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
        }
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
            Color.black.opacity(0.5).ignoresSafeArea()
            CascadingCardsView()

            if let run = controller.run {
                ScrollView {
                    VStack(spacing: 22) {
                        Text(run.stage == .boss ? "Chapter Complete!" : "Round Cleared!")
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
                                totalRow("Round score", value: controller.stageScore, highlight: true)
                                totalRow("Target", value: run.target, highlight: false)
                                totalRow("Journey total", value: run.totalScore, highlight: false)
                            }
                            .opacity(showTotals ? 1 : 0)
                        }
                        .padding(24)
                        .frame(maxWidth: 620)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.6)))

                        Button {
                            controller.showCharmChoices()
                        } label: {
                            Label("Choose a Charm", systemImage: "sparkles")
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
    @State private var selected: Charm?

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("Choose a Charm")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                    Text("Your charm helps you in every round for the rest of the journey.")
                        .font(Theme.rounded(.title2))
                        .opacity(0.85)
                        .multilineTextAlignment(.center)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) { charmCards(width: 280) }
                    VStack(spacing: 16) { charmCards(width: 520) }
                }

                Button {
                    if let selected { controller.chooseCharm(selected) }
                } label: {
                    Text(selected.map { "Take “\($0.title)”" } ?? "Tap a charm to choose it")
                }
                .buttonStyle(BigButtonStyle())
                .frame(maxWidth: 520)
                .disabled(selected == nil)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func charmCards(width: CGFloat) -> some View {
        ForEach(controller.run?.offeredCharms ?? []) { charm in
            Button {
                withAnimation(.spring(duration: 0.3)) { selected = charm }
                controller.playTick()
            } label: {
                CharmChoiceCard(charm: charm, isSelected: selected == charm)
                    .frame(width: width)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CharmChoiceCard: View {
    let charm: Charm
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(spacing: 16) {
            CharmIcon(charm: charm, size: 88)
            Text(charm.title)
                .font(Theme.rounded(.title, weight: .bold))
                .multilineTextAlignment(.center)
            Text(charm.detail)
                .font(Theme.rounded(.title2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Label(isSelected ? "Chosen" : "Tap to choose", systemImage: isSelected ? "checkmark.circle.fill" : "hand.tap.fill")
                .font(Theme.rounded(.title3, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.gold : .white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 340)
        .background(shape.fill(isSelected ? charm.tint.opacity(0.25) : Color.black.opacity(0.32)))
        .overlay(shape.strokeBorder(isSelected ? Theme.gold : Color.white.opacity(0.25), lineWidth: isSelected ? 5 : 2))
        .scaleEffect(isSelected ? 1.03 : 1)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
