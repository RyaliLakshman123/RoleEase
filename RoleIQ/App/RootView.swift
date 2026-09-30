//
//  RootView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

//MARK: RootView launch flow is bypassed — restore before archive.
//
//  TEMP: bypassing splash/signIn/home so ResumeUploadView opens directly
//  for testing the ATS feature. Restore the switch-based body below once done.
//


import SwiftUI
import SwiftData

struct RootView: View {
    @State private var router = AppRouter()
    @State private var authViewModel = AuthViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var hasInitializedLaunchFlow = false

    private func destinationAfterAuth() -> AppScreen {
        if authViewModel.isSignedIn {
            let hasName = !(authViewModel.userName ?? "").isEmpty
            return hasName ? .home : .nameEntry
        }

        if authViewModel.isGuest {
            return .home
        }

        return .signIn
    }

    var body: some View {
        Group {
            if hasInitializedLaunchFlow {
                switch router.currentScreen {
                case .onboarding:
                    OnboardingView {
                        hasSeenOnboarding = true
                        router.go(to: destinationAfterAuth())
                    }

                case .signIn:
                    SignInView()

                case .nameEntry:
                    NameEntryView {
                        router.go(to: .home)
                    }

                case .home:
                    RootTabView()
                }
            } else {
                // Keep the initial launch screen hidden
                // until we determine where the user should go.
                Color.black
                    .ignoresSafeArea()
            }
        }
        .environment(authViewModel)
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !hasInitializedLaunchFlow else { return }

            if !hasSeenOnboarding {
                router.go(to: .onboarding)
            } else {
                router.go(to: destinationAfterAuth())
            }

            hasInitializedLaunchFlow = true
        }
        .onChange(of: authViewModel.isSignedIn) { _, _ in
            guard hasInitializedLaunchFlow else { return }

            if hasSeenOnboarding {
                router.go(to: destinationAfterAuth())
            }
        }
        .onChange(of: authViewModel.isGuest) { _, _ in
            guard hasInitializedLaunchFlow else { return }

            if hasSeenOnboarding {
                router.go(to: destinationAfterAuth())
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SubscriptionManager())
        .modelContainer(
            for: [
                ResumeItem.self,
                ChatSessionEntity.self,
                SavedJob.self,
                ATSHistoryItem.self,
                InterviewSessionEntity.self
            ],
            inMemory: true
        )
}
