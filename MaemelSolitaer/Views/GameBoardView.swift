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
            // iPhone-sized width: everything is stacked and scaled to fit.
            let isNarrow = proxy.size.width < 600
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
                    VStack(spacing: isNarrow ? 10 : 14) {
                        GameHeaderView(isCompact: true, isNarrow: isNarrow)
                        tableArea
                        CharmStrip(isRow: true, isNarrow: isNarrow)
                        ControlPanel(isVertical: false, isNarrow: isNarrow, showMenu: $showMenu)
                    }
                }
            }
            .padding(isNarrow ? 10 : 16)
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
            .overlay {
                if controller.isDealing {
                    ShufflingPanel()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: controller.isDealing)
    }
}

// MARK: - Header

struct GameHeaderView: View {
    @Environment(GameController.self) private var controller
    /// Portrait: the round rule gets its own full-width line so it is never squeezed.
    var isCompact = false
    /// Phone width: score gauge gets its own full-width row.
    var isNarrow = false

    var body: some View {
        if let run = controller.run {
            Group {
                if isNarrow {
                    VStack(alignment: .leading, spacing: 8) {
                        stageLabels(run)
                        scoreGauge(run)
                        ConditionPill(condition: run.condition, moveCount: controller.game.moveCount)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if isCompact {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 18) {
                            stageLabels(run)
                            Spacer(minLength: 8)
                            scoreGauge(run)
                        }
                        ConditionPill(condition: run.condition, moveCount: controller.game.moveCount)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        stageLabels(run)
                        ConditionPill(condition: run.condition, moveCount: controller.game.moveCount)
                        Spacer(minLength: 8)
                        scoreGauge(run)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .panelBackground(cornerRadius: 20)
        }
    }

    private func stageLabels(_ run: RunState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Chapter \(run.ante) · \(run.difficulty.title)", systemImage: run.difficulty.symbolName)
                .font(Theme.rounded(.headline, weight: .semibold))
                .opacity(0.85)
            Label(run.stage.title, systemImage: run.stage.symbolName)
                .font(Theme.rounded(.title2, weight: .bold))
        }
        .fixedSize()
    }

    private func scoreGauge(_ run: RunState) -> some View {
        ScoreGauge(score: controller.stageScore, target: run.target, compact: isNarrow)
    }
}

struct ConditionPill: View {
    let condition: StageCondition
    let moveCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: condition.symbolName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(condition.isChallenge ? Color(red: 1.0, green: 0.68, blue: 0.45) : Theme.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(condition.title)
                    .font(Theme.rounded(.title3, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(Theme.rounded(.body))
                    .opacity(0.9)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if condition == .moveBudget {
            return String(localized: "Moves: \(moveCount) of \(StageCondition.moveBudgetLimit)")
        }
        return condition.detail
    }
}

/// Large, clearly labelled score and target, readable at arm's length.
/// Large, clearly labelled score and target, readable at arm's length.
/// Gains count up step by step (1, flash, 2, flash, …) — at most one second per gain.
struct ScoreGauge: View {
    let score: Int
    let target: Int
    /// Phone width: smaller numbers and a bar that fills the available width.
    var compact = false

    private let barWidth: CGFloat = 330

    /// The number currently shown; trails `score` while counting up.
    @State private var shown: Int?
    @State private var flashes = 0
    @State private var flashLength = 0.1
    @State private var countTask: Task<Void, Never>?

    var body: some View {
        let current = shown ?? score
        let progress = target > 0 ? min(1, Double(current) / Double(target)) : 0
        let reached = current >= target
        VStack(alignment: compact ? .leading : .trailing, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: compact ? 28 : 18) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("SCORE")
                        .font(Theme.rounded(.headline, weight: .bold))
                        .opacity(0.8)
                    Text(current, format: .number)
                        .font(.system(size: compact ? 46 : 64, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .keyframeAnimator(initialValue: ScoreFlash(), trigger: flashes) { content, flash in
                            content
                                .scaleEffect(flash.scale, anchor: .trailing)
                                .foregroundStyle(Color.white.mix(with: Theme.gold, by: flash.glow))
                                .shadow(color: Theme.gold.opacity(flash.glow), radius: 14)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                CubicKeyframe(1.16, duration: flashLength * 0.35)
                                CubicKeyframe(1.0, duration: flashLength * 0.65)
                            }
                            KeyframeTrack(\.glow) {
                                LinearKeyframe(1.0, duration: flashLength * 0.25)
                                LinearKeyframe(0.0, duration: flashLength * 0.75)
                            }
                        }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text("TARGET")
                        .font(Theme.rounded(.headline, weight: .bold))
                        .opacity(0.8)
                    Text(target, format: .number)
                        .font(.system(size: compact ? 46 : 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(reached ? Theme.success : Theme.gold)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(reached ? Theme.success : Theme.gold)
                    .scaleEffect(x: max(progress, 0.001), anchor: .leading)
            }
            .frame(width: compact ? nil : barWidth, height: compact ? 14 : 20)
            .frame(maxWidth: compact ? .infinity : nil)
        }
        .animation(.easeOut(duration: 0.15), value: current)
        .onAppear { shown = score }
        .onChange(of: score) { _, newScore in
            countUp(to: newScore)
        }
        .onDisappear { countTask?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reached ? String(localized: "Score \(score) of \(target), target reached") : String(localized: "Score \(score) of \(target)"))
    }
}

extension ScoreGauge {
    /// Counts the displayed score up to `newScore`, flashing on every step.
    /// Drops (undo, penalties, a new deal) are shown at once.
    private func countUp(to newScore: Int) {
        countTask?.cancel()
        let start = shown ?? newScore
        let difference = newScore - start
        guard difference > 0 else {
            shown = newScore
            return
        }
        let duration = GameController.countUpDuration(for: difference)
        // One step per point, capped so very large bonuses still finish in one second.
        let steps = min(difference, 40)
        let interval = duration / Double(steps)
        flashLength = min(0.16, max(0.05, interval))
        countTask = Task {
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                shown = start + Int((Double(difference) * Double(step) / Double(steps)).rounded())
                flashes += 1
            }
        }
    }
}

/// Values animated by the score flash.
private struct ScoreFlash {
    var scale = 1.0
    var glow = 0.0
}

/// Shown while a guaranteed-winnable deal is being prepared.
private struct ShufflingPanel: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Shuffling the cards…")
                .font(Theme.rounded(.title, weight: .bold))
            Text("Making sure this game can be won.")
                .font(Theme.rounded(.title3))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(36)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.65)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Controls

struct ControlPanel: View {
    @Environment(GameController.self) private var controller
    let isVertical: Bool
    /// Phone width: shorter buttons, with action buttons in their own row above Undo/Hint/Menu.
    var isNarrow = false
    @Binding var showMenu: Bool

    private var buttonHeight: CGFloat { isNarrow ? 86 : 88 }

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: 12) {
                    undoButton
                    hintButton
                    actionButtons
                    if controller.targetReached {
                        // Nudge towards clearing the board for the bonus charm.
                        Label("Clear the board to get 2 charms", systemImage: "sparkles")
                            .font(Theme.rounded(.headline, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    CharmStrip()
                    menuButton
                }
                .frame(width: 176)
            } else {
                VStack(spacing: isNarrow ? 8 : 12) {
                    HStack(spacing: isNarrow ? 8 : 12) { actionButtons }
                    HStack(spacing: isNarrow ? 8 : 12) {
                        undoButton
                        hintButton
                        menuButton
                    }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: controller.canAutoComplete)
        .animation(.spring(duration: 0.35), value: controller.targetReached)
        .animation(.spring(duration: 0.35), value: controller.isStuck)
    }

    private var undoButton: some View {
        ControlButton(title: String(localized: "Undo"), subtitle: costText(controller.undoCost),
                      systemImage: "arrow.uturn.backward", minHeight: buttonHeight, fixedHeight: isNarrow) {
            controller.undo()
        }
        .disabled(!controller.canUndo)
    }

    private var hintButton: some View {
        ControlButton(title: String(localized: "Hint"), subtitle: costText(controller.hintCost),
                      systemImage: "lightbulb.fill", minHeight: buttonHeight, fixedHeight: isNarrow) {
            controller.showHint()
        }
        .disabled(!controller.canInteract)
    }

    private var menuButton: some View {
        ControlButton(title: String(localized: "Menu"), subtitle: nil, systemImage: "line.3.horizontal",
                      minHeight: buttonHeight, fixedHeight: isNarrow) {
            showMenu = true
        }
    }

    /// Auto-Finish, Finish Round and End Round, shown only when they apply.
    @ViewBuilder
    private var actionButtons: some View {
        if controller.canAutoComplete {
            ControlButton(title: String(localized: "Auto-Finish"), subtitle: String(localized: "Play all cards"),
                          systemImage: "wand.and.stars", isProminent: true, minHeight: buttonHeight, fixedHeight: isNarrow) {
                controller.autoComplete()
            }
        }
        if controller.targetReached {
            ControlButton(title: String(localized: "Finish Round"), subtitle: String(localized: "Get 1 charm"),
                          systemImage: "checkmark.circle.fill", isProminent: true, minHeight: buttonHeight, fixedHeight: isNarrow) {
                controller.finishRound()
            }
            .disabled(!controller.canInteract)
        } else if controller.isStuck {
            ControlButton(title: String(localized: "End Round"), subtitle: String(localized: "No moves left"),
                          systemImage: "flag.fill", isProminent: true, minHeight: buttonHeight, fixedHeight: isNarrow) {
                controller.finishRound()
            }
            .disabled(!controller.canInteract)
        }
    }

    private func costText(_ cost: Int) -> String {
        cost == 0 ? String(localized: "Free") : String(localized: "−\(cost) points")
    }
}

struct ControlButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var isProminent = false
    var minHeight: CGFloat = 88
    /// Exactly `minHeight` tall, so buttons with and without a subtitle line up.
    var fixedHeight = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            VStack(spacing: fixedHeight ? 2 : 4) {
                Image(systemName: systemImage)
                    .font(.system(size: fixedHeight ? 22 : 28, weight: .semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.rounded(fixedHeight ? .headline : .title3, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.rounded(.subheadline, weight: .medium))
                        .opacity(0.85)
                }
            }
            .padding(.vertical, fixedHeight ? 6 : 0)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fixedHeight ? minHeight : nil)
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
    /// Portrait shows the 9 slots in one row under the table.
    var isRow = false
    /// Phone width: smaller icons with the heading above them.
    var isNarrow = false

    var body: some View {
        if let charms = controller.run?.charms {
            if isRow {
                let size: CGFloat = isNarrow ? 34 : 44
                let title = Text("Charms \(charms.count)/\(RunState.maxCharms)")
                    .font(Theme.rounded(isNarrow ? .subheadline : .headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                let icons = HStack(spacing: isNarrow ? 6 : 10) {
                    ForEach(0..<RunState.maxCharms, id: \.self) { index in
                        slot(index, charms: charms, size: size)
                    }
                }
                Group {
                    if isNarrow {
                        VStack(spacing: 6) { title; icons }
                    } else {
                        HStack(spacing: 10) {
                            title.fixedSize()
                            Spacer(minLength: 0)
                            icons
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .panelBackground(cornerRadius: 18)
            } else {
                grid(charms)
            }
        }
    }

    @ViewBuilder
    private func slot(_ index: Int, charms: [Charm], size: CGFloat = 44) -> some View {
        if index < charms.count {
            FlashingCharmIcon(charm: charms[index], size: size)
        } else {
            Circle()
                .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private func grid(_ charms: [Charm]) -> some View {
            VStack(spacing: 8) {
                Text("Charms \(charms.count)/\(RunState.maxCharms)")
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(0..<3, id: \.self) { row in
                        GridRow {
                            ForEach(0..<3, id: \.self) { column in
                                slot(row * 3 + column, charms: charms)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .panelBackground(cornerRadius: 18)
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
