//
//  SettingsView.swift
//  MaemelSolitaer
//
//  Settings and a plain-language rules page.
//

import SwiftUI

struct SettingsView: View {
    @Environment(GameController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = controller.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                SettingsSection(title: String(localized: "Cards to Turn Over"), detail: String(localized: "Takes effect with the next deal.")) {
                    OptionButton(title: String(localized: "1 card at a time (relaxed)"), isSelected: !settings.drawThree) {
                        controller.updateSettings { $0.drawThree = false }
                    }
                    OptionButton(title: String(localized: "3 cards at a time (classic)"), isSelected: settings.drawThree) {
                        controller.updateSettings { $0.drawThree = true }
                    }
                }

                SettingsSection(title: String(localized: "Table Color"), detail: nil) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(TableColor.allCases) { color in
                            Button {
                                controller.updateSettings { $0.tableColor = color }
                            } label: {
                                VStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(LinearGradient(colors: color.colors, startPoint: .top, endPoint: .bottom))
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(settings.tableColor == color ? Theme.gold : Color.white.opacity(0.3),
                                                              lineWidth: settings.tableColor == color ? 5 : 2)
                                        )
                                    Text(color.title)
                                        .font(Theme.rounded(.title3, weight: settings.tableColor == color ? .bold : .regular))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(settings.tableColor == color ? .isSelected : [])
                        }
                    }
                }

                SettingsSection(title: String(localized: "Comfort"), detail: nil) {
                    LargeToggle(title: String(localized: "Sound effects"), isOn: settings.soundOn) { value in
                        controller.updateSettings { $0.soundOn = value }
                    }
                    LargeToggle(title: String(localized: "Buttons on the left side"), isOn: settings.leftHanded) { value in
                        controller.updateSettings { $0.leftHanded = value }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(Theme.rounded(.title3, weight: .bold))
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.rounded(.title, weight: .bold))
                if let detail {
                    Text(detail)
                        .font(Theme.rounded(.title3))
                        .opacity(0.75)
                }
            }
            content
        }
    }
}

private struct OptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.gold : .white.opacity(0.6))
                Text(title)
                    .font(Theme.rounded(.title2, weight: isSelected ? .bold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(shape.fill(isSelected ? Theme.gold.opacity(0.18) : Color.white.opacity(0.08)))
            .overlay(shape.strokeBorder(isSelected ? Theme.gold : Color.white.opacity(0.3), lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LargeToggle: View {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { onChange($0) })) {
            Text(title)
                .font(Theme.rounded(.title2))
        }
        .toggleStyle(.switch)
        .tint(Theme.gold)
        .padding(.horizontal, 20)
        .frame(minHeight: 70)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(String, String, String)] = [
        ("flag.checkered", String(localized: "The Goal"),
         String(localized: "Move all cards to the four piles at the top, from Ace up to King. Each pile holds one suit.")),
        ("rectangle.split.3x1.fill", String(localized: "The Columns"),
         String(localized: "Build the columns downward with alternating colors — for example a red 6 on a black 7. Only a King can go into an empty column.")),
        ("rectangle.stack.fill", String(localized: "The Deck"),
         String(localized: "Tap the deck to turn over cards. When it is empty, tap it again to start over.")),
        ("hand.tap.fill", String(localized: "Moving Cards"),
         String(localized: "Tap a card and it jumps to the best place. Or drag it — you don't need to be precise, it snaps into place.")),
        ("dial.medium.fill", String(localized: "Difficulty"),
         String(localized: "Easy is the classic game. Medium adds an eighth column. Hard uses two decks, nine columns and eight foundation piles. Every deal is checked in advance so it can always be won.")),
        ("crown.fill", String(localized: "Chapters and Rounds"),
         String(localized: "Each chapter has three rounds: Warm-Up, Main and Boss. Reach the target score to clear a round. There is no timer — take all the time you like.")),
        ("sparkles", String(localized: "Charms"),
         String(localized: "After each cleared round you choose one charm — or two if you cleared the whole board, so it pays to finish even after reaching the target. Charms give you bonus points for the rest of the journey. You have 9 charm slots — when they are full, remove one of your charms to make room, or keep the ones you have.")),
        ("lightbulb.fill", String(localized: "Helpers"),
         String(localized: "Undo takes back a move. Hint shows a good move in gold. Auto-Finish appears once all cards are face up and plays them for you.")),
        ("star.fill", String(localized: "Points"),
         String(localized: "Card to the foundation: 10. Turning over a card: 5. Deck card onto a column: 5. Clearing the board: 250. Undo costs 5.")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ForEach(sections, id: \.1) { icon, title, text in
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 48)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(Theme.rounded(.title, weight: .bold))
                            Text(text)
                                .font(Theme.rounded(.title3))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .navigationTitle("How to Play")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(Theme.rounded(.title3, weight: .bold))
            }
        }
    }
}
