//
//  ChatContainer.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 27/08/26.
//


//
//  Wraps the Chat tab's ChatView so it slides right to reveal the
//  ChatHistorySidebar underneath — ChatGPT/Gemini iOS style.
//  Owns the isSidebarOpen state and passes it down as a binding.
//


import SwiftUI
import SwiftData

struct ChatContainer: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let entity: ChatSessionEntity
    let userName: String
    @Binding var isSidebarOpen: Bool

    var onNewChat: (() -> Void)? = nil
    // Bubbles the tapped history session up to RootTabView so it can swap the
    // active chatEntity. Previously this container swallowed the selection
    // ({ _ in }) and only closed the drawer, so tapping history did nothing.
    var onSelectSession: ((ChatSessionEntity) -> Void)? = nil
    var onOpenProfile: (() -> Void)? = nil
    var onDeleteSession: ((ChatSessionEntity) -> Void)? = nil

    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let sidebarWidth = fullWidth * 0.85

            HStack(spacing: 0) {

                // Sidebar sits to the LEFT of the chat, off-screen when closed
                ChatHistorySidebar(
                    onSelectSession: { session in
                        onSelectSession?(session)
                        closeSidebar()
                    },
                    onNewChat: {
                        onNewChat?()
                        closeSidebar()
                    },
                    onOpenSettings: { showSettings = true },
                    onDeleteSession: { session in
                        onDeleteSession?(session)
                    }
                )
                .frame(width: sidebarWidth)

                // Chat sits to the RIGHT, full screen width
                ChatView(
                    entity: entity,
                    userName: userName,
                    onNewChat: onNewChat,
                    onOpenProfile: onOpenProfile,
                    isSidebarOpen: $isSidebarOpen
                )
                .frame(width: fullWidth)
                .overlay {
                    if isSidebarOpen {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { Haptics.tap(); closeSidebar() }
                    }
                }
            }
            // Whole stack is (sidebarWidth + fullWidth) wide.
            // Closed: shift left by sidebarWidth so only the chat shows.
            // Open: shift to 0 so the sidebar slides into view.
            .frame(width: sidebarWidth + fullWidth, alignment: .leading)
            .offset(x: isSidebarOpen ? 0 : -sidebarWidth)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSidebarOpen)
        }
        .background(ChatTheme.backgroundGradient.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(subscriptionManager)
        }
    }

    private func closeSidebar() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isSidebarOpen = false
        }
    }
}
