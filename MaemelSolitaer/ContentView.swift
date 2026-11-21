//
//  ContentView.swift
//  MaemelSolitaer
//
//  Created by Hauke Bartsch on 15/11/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var controller = GameController()

    var body: some View {
        ZStack {
            FeltBackground(color: controller.settings.tableColor)
            screenContent
        }
        .environment(controller)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: controller.screen)
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #endif
    }

    @ViewBuilder
    private var screenContent: some View {
        switch controller.screen {
        case .menu:
            MainMenuView()
                .transition(.opacity)
        case .chooseDifficulty:
            DifficultyPickerView()
                .transition(.opacity)
        case .stageIntro:
            StageIntroView()
                .transition(.opacity)
        case .playing, .stageComplete, .stageFailed:
            // The table stays visible (but inactive) behind the end-of-round screens.
            ZStack {
                GameBoardView()
                    .allowsHitTesting(controller.screen == .playing)
                if controller.screen == .stageComplete {
                    StageCompleteView()
                        .transition(.opacity)
                }
                if controller.screen == .stageFailed {
                    StageFailedView()
                        .transition(.opacity)
                }
            }
            .transition(.opacity)
        case .charmPick:
            CharmPickerView()
                .id(controller.run?.charmPicksRemaining ?? 0)
                .transition(.opacity)
        case .journeyComplete:
            JourneyCompleteView()
                .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
}
