//
//  GameBoardView.swift
//  MaemelSolitaer
//
//  The playing screen: header with score, the table, and large assist buttons.
//

import SwiftUI

struct GameBoardView: View {
    @Environment(GameController.self) private var controller
    @State private var showMenu = false

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height
            Group {
                if isWide {
                    // Landscape: buttons in a sidebar (left or right, per settings).
                    HStack(alignment: .top, spacing: 16) {
                        if controller.settings.leftHanded {
                            ControlPanel(isVertical: true, showMenu: $showMenu)
                        }
                        VStack(spacing: 14) {
                            GameHeaderView()
                            tableArea
                        }
                        if !controller.settings.leftHanded {
                            ControlPanel(isVertical: true, showMenu: $showMenu)
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        GameHeaderView()
                        tableArea
                        ControlPanel(isVertical: false, showMenu: $showMenu)
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showMenu) {
            GameMenuSheet()
                .environment(controller)
        }
    }

    private var tableArea: some View {
        TableView()
            .overlay(alignment: .bottom) {
                MessageBanner()
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Header

struct GameHeaderView: View {
    @Environment(GameController.self) private var controller
    @State private var showGain = false
    @State private var hasAppeared = false

    var body: some View {
        if let run = controller.run {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapter \(run.ante)")
                        .font(Theme.rounded(.headline, weight: .semibold))
                        .opacity(0.8)
                    Label(run.stage.title, systemImage: run.stage.symbolName)
                        .font(Theme.rounded(.title2, weight: .bold))
                }
                .fixedSize()

                ConditionPill(condition: run.condition, moveCount: controller.game.moveCount)

                Spacer(minLength: 8)

                ScoreGauge(score: controller.stageScore, target: run.target,
                           gain: showGain ? controller.lastGain : nil)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .panelBackground(cornerRadius: 20)
            .task(id: controller.gainToken) {
                // Skip the first run so a stale gain isn't shown on appear.
                guard hasAppeared else {
                    hasAppeared = true
                    return
                }
                withAnimation(.spring(duration: 0.3)) { showGain = true }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.3)) { showGain = false }
            }
        }
    }
}

struct ConditionPill: View {
    let condition: StageCondition
    let moveCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: condition.symbolName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(condition.isChallenge ? Color(red: 1.0, green: 0.68, blue: 0.45) : Theme.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(condition.title)
                    .font(Theme.rounded(.headline, weight: .bold))
                Text(subtitle)
                    .font(Theme.rounded(.subheadline))
                    .opacity(0.85)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if condition == .moveBudget {
            return "Moves: \(moveCount) of \(StageCondition.moveBudgetLimit)"
        }
        return condition.detail
    }
}

struct ScoreGauge: View {
    let score: Int
    let target: Int
    let gain: Int?

    private let barWidth: CGFloat = 240

    var body: some View {
        let progress = target > 0 ? min(1, Double(score) / Double(target)) : 0
        let reached = score >= target
        VStack(alignment: .trailing, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let gain {
                    Text("+\(gain)")
                        .font(Theme.rounded(.title2, weight: .heavy))
                        .foregroundStyle(Theme.success)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Text(score, format: .number)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(score)))
                Text("/ \(target.formatted())")
                    .font(Theme.rounded(.title3, weight: .semibold))
                    .opacity(0.8)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(reached ? Theme.success : Theme.gold)
                    .frame(width: barWidth * progress)
            }
            .frame(width: barWidth, height: 14)
        }
        .animation(.spring(duration: 0.4), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) of \(target)\(reached ? ", target reached" : "")")
    }
}

// MARK: - Controls

struct ControlPanel: View {
    @Environment(GameController.self) private var controller
    let isVertical: Bool
    @Binding var showMenu: Bool

    var body: some View {
        let layout = isVertical ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            ControlButton(title: "Undo", subtitle: costText(controller.undoCost), systemImage: "arrow.uturn.backward") {
                controller.undo()
            }
            .disabled(!controller.canUndo)

            ControlButton(title: "Hint", subtitle: costText(controller.hintCost), systemImage: "lightbulb.fill") {
                controller.showHint()
            }
            .disabled(!controller.canInteract)

            if controller.canAutoComplete {
                ControlButton(title: "Auto-Finish", subtitle: "Play all cards", systemImage: "wand.and.stars", isProminent: true) {
                    controller.autoComplete()
                }
            }

            if controller.targetReached {
                ControlButton(title: "Finish Round", subtitle: "Target reached!", systemImage: "checkmark.circle.fill", isProminent: true) {
                    controller.finishRound()
                }
                .disabled(!controller.canInteract)
            } else if controller.isStuck {
                ControlButton(title: "End Round", subtitle: "No moves left", systemImage: "flag.fill", isProminent: true) {
                    controller.finishRound()
                }
                .disabled(!controller.canInteract)
            }

            if isVertical {
                Spacer(minLength: 0)
                CharmStrip()
            }

            ControlButton(title: "Menu", subtitle: nil, systemImage: "line.3.horizontal") {
                showMenu = true
            }
        }
        .frame(width: isVertical ? 176 : nil)
        .animation(.spring(duration: 0.35), value: controller.canAutoComplete)
        .animation(.spring(duration: 0.35), value: controller.targetReached)
        .animation(.spring(duration: 0.35), value: controller.isStuck)
    }

    private func costText(_ cost: Int) -> String {
        cost == 0 ? "Free" : "−\(cost) points"
    }
}

struct ControlButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var isProminent = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                Text(title)
                    .font(Theme.rounded(.title3, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.rounded(.subheadline, weight: .medium))
                        .opacity(0.85)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(shape.fill(isProminent ? Theme.gold : Color.white.opacity(0.13)))
            .overlay(shape.strokeBorder(Color.white.opacity(isProminent ? 0 : 0.3), lineWidth: 1.5))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

/// Compact display of the charms collected so far.
struct CharmStrip: View {
    @Environment(GameController.self) private var controller

    var body: some View {
        if let charms = controller.run?.charms, !charms.isEmpty {
            VStack(spacing: 8) {
                Text("Charms")
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 8), count: 3), spacing: 8) {
                        ForEach(charms) { charm in
                            CharmIcon(charm: charm, size: 46)
                        }
                    }
                }
                .frame(maxHeight: 170)
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(10)
            .panelBackground(cornerRadius: 18)
        }
    }
}

// MARK: - Menu

struct GameMenuSheet: View {
    @Environment(GameController.self) private var controller
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRedeal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back to the Game", systemImage: "play.fill")
                    }
                    .buttonStyle(BigButtonStyle())

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))

                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        Label("How to Play", systemImage: "questionmark.circle.fill")
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))

                    Button {
                        confirmRedeal = true
                    } label: {
                        Label("Deal New Cards", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))

                    Button {
                        dismiss()
                        controller.returnToMenu()
                    } label: {
                        Label("Save and Go to Main Menu", systemImage: "house.fill")
                    }
                    .buttonStyle(BigButtonStyle(kind: .secondary))
                }
                .padding(28)
            }
            .navigationTitle("Menu")
        }
        .presentationBackground(Theme.sheetBackground)
        .alert("Deal new cards?", isPresented: $confirmRedeal) {
            Button("Deal New Cards") {
                dismiss()
                controller.dealStage()
            }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("This round starts over with a fresh deal, and the round score goes back to zero.")
        }
    }
}
