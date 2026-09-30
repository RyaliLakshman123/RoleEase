//
//  RootTabView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 27/08/26.
//


//
//  The app's main tab bar. Home = Chat. Every feature is one tap away.
//

import SwiftUI
import SwiftData
import RevenueCatUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var selectedTab = 0
    @State private var chatEntity: ChatSessionEntity?

    // Owned here so the tab bar can hide when the sidebar opens.
    @State private var isSidebarOpen = false

    // One-time cleanup guard so we don't sweep empties on every re-render.
    @State private var didCleanUpEmpties = false
    @State private var showPaywall = false
    
    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Tab 1 — Chat (Home)
            Group {
                if let chatEntity {
                    ChatContainer(
                        entity: chatEntity,
                        userName: authViewModel.userName ?? "there",
                        isSidebarOpen: $isSidebarOpen,
                        onNewChat: startNewChat,
                        onSelectSession: openSession,
                        onOpenProfile: { Haptics.medium(); showPaywall = true },
                        onDeleteSession: handleDeletedSession
                    )
                    // Force a fresh ChatView (and its @StateObject VM) whenever the
                    // session changes, so switching chats reloads cleanly.
                    .id(chatEntity.id)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .toolbar(isSidebarOpen ? .hidden : .visible, for: .tabBar)
            .tabItem {
                Label("Chat", systemImage: selectedTab == 0 ? "message.fill" : "message")
            }
            .tag(0)
            
            // MARK: Tab 2 — Interview
            MockInterviewView(onOpenProfile: { Haptics.medium(); showPaywall = true })
                .tabItem {
                    Label("Interview", systemImage: selectedTab == 1 ? "mic.fill" : "mic")
                }
                .tag(1)

            // MARK: Tab 3 — Jobs
            JobsDashboardView()
                .tabItem {
                    Label("Jobs", systemImage: selectedTab == 2 ? "briefcase.fill" : "briefcase")
                }
                .tag(2)

            // MARK: Tab 4 — Prep
            ResumeUploadView(onOpenProfile: { Haptics.medium(); showPaywall = true })
                .tabItem {
                    Label("Prep", systemImage: selectedTab == 3 ? "doc.text.fill" : "doc.text")
                }
                .tag(3)
        }
        .tint(violet)
        .onChange(of: selectedTab) { _, _ in
            Haptics.tap()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSidebarOpen)
        .onAppear {
            configureTabBarAppearance()
            cleanUpEmptySessionsOnce()
            if chatEntity == nil {
                chatEntity = ChatSessionEntity()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in showPaywall = false }
                .onRestoreCompleted { _ in showPaywall = false }
        }
    }

    // MARK: - Session handling

    /// Start a brand-new draft chat. The old draft, if it was never messaged,
    /// is discarded automatically because it was never inserted into the context.
    private func startNewChat() {
        chatEntity = ChatSessionEntity()
    }

    /// Open an existing chat from history. If the current chat is an unsaved
    /// draft (never inserted, i.e. no messages), it simply falls away when we
    /// replace it — no ghost row left behind.
    private func openSession(_ session: ChatSessionEntity) {
        chatEntity = session
        selectedTab = 0
    }
    
    /// The sidebar deleted a session. If it's the one we're currently showing,
    /// replace it with a fresh draft so ChatView isn't rendering a deleted
    /// object (which shows a ghost chat and can crash on later access).
    private func handleDeletedSession(_ session: ChatSessionEntity) {
        guard session.id == chatEntity?.id else { return }
        chatEntity = ChatSessionEntity()   // fresh empty draft, same as New Chat
    }

    // MARK: - One-time cleanup
    // Removes any previously-persisted empty sessions left over from the old
    // behaviour (which saved a blank chat on every launch). "Empty" means zero
    // messages — NOT an empty title, since the model defaults title to
    // "New Chat". messages is a computed JSON-decoded property, so it can't be
    // used inside a #Predicate; we fetch all and filter in Swift. Chat history
    // is small, so this is cheap.

    private func cleanUpEmptySessionsOnce() {
        guard !didCleanUpEmpties else { return }
        didCleanUpEmpties = true

        let descriptor = FetchDescriptor<ChatSessionEntity>()
        guard let all = try? modelContext.fetch(descriptor) else { return }

        // A chat is only "empty" if it never got a title, preview, OR messages.
        // Requiring all three protects real chats from a single failed JSON
        // decode (messages would falsely read as [] and delete a real chat).
        var removedAny = false
        for session in all
        where session.messages.isEmpty
            && session.preview.isEmpty
            && (session.title == "New Chat" || session.title.isEmpty) {
            modelContext.delete(session)
            removedAny = true
        }
        if removedAny {
            try? modelContext.save()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    RootTabView()
        .environment(AuthViewModel())
        .modelContainer(for: [
            ResumeItem.self,
            ChatSessionEntity.self,
            SavedJob.self,
            ATSHistoryItem.self,
            InterviewSessionEntity.self
        ], inMemory: true)
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
