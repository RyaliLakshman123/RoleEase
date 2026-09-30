//
//  SidebarContainer.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 27/08/26.
//


//
//  Wraps the Chat screen so it slides right to reveal ChatHistorySidebar
//  underneath — ChatGPT/Gemini iOS style. The sidebar is the bottom layer;
//  the foreground (ChatView) offsets + scales to expose it.
//

import SwiftUI
import SwiftData

struct SidebarContainer<Foreground: View>: View {

    @Binding var isOpen: Bool

    let sidebar: ChatHistorySidebar
    let foreground: Foreground

    // How far the foreground slides open (fraction of screen width)
    private let revealFraction: CGFloat = 0.82

    init(
        isOpen: Binding<Bool>,
        sidebar: ChatHistorySidebar,
        @ViewBuilder foreground: () -> Foreground
    ) {
        self._isOpen = isOpen
        self.sidebar = sidebar
        self.foreground = foreground()
    }

    var body: some View {
        GeometryReader { geo in
            let revealWidth = geo.size.width * revealFraction

            ZStack(alignment: .leading) {
                // Bottom layer: the sidebar
                sidebar
                    .frame(width: revealWidth)

                // Top layer: the chat screen, slides right when open
                foreground
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(isOpen ? 0.92 : 1.0, anchor: .leading)
                    .offset(x: isOpen ? revealWidth : 0)
                    .overlay {
                        // Tap-to-close scrim over the chat while open
                        if isOpen {
                            Color.black.opacity(0.001)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                        isOpen = false
                                    }
                                }
                        }
                    }
                    .shadow(color: .black.opacity(isOpen ? 0.35 : 0), radius: 18, x: -6, y: 0)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isOpen)
        }
        .ignoresSafeArea()
    }
}


// MARK: - Preview

#Preview {
    // Wrapper gives us @State so the toggle actually animates in the canvas
    struct PreviewHost: View {
        @State private var isOpen = false

        var body: some View {
            let container = try! ModelContainer(
                for: ChatSessionEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            // Seed a few sample sessions so the sidebar isn't empty
            let samples: [(String, CareerMode)] = [
                ("Evaluate remote contract job", .general),
                ("Infosys internship resume review", .resumeReview),
                ("Mock interview — backend role", .mockInterview)
            ]
            for (title, mode) in samples {
                let session = ChatSessionEntity(title: title, mode: mode)
                session.preview = "Sample preview text for \(title)."
                container.mainContext.insert(session)
            }

            return SidebarContainer(
                isOpen: $isOpen,
                sidebar: ChatHistorySidebar(
                    onSelectSession: { _ in
                        withAnimation { isOpen = false }
                    },
                    onNewChat: { withAnimation { isOpen = false } },
                    onOpenSettings: {}
                )
            ) {
                // Stand-in for ChatView — a black screen with a working hamburger
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()

                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            isOpen.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)

                    Text("ChatView goes here")
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .modelContainer(container)
        }
    }

    return PreviewHost()
}
