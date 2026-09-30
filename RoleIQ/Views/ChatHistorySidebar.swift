//
//  ChatHistorySidebar.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//


//
//  ChatGPT/Gemini-style drawer content: search + flat Recents list.
//  Backed by SwiftData @Query on ChatSessionEntity (single source of truth).


import SwiftUI
import SwiftData

struct ChatHistorySidebar: View {

    @Query(sort: \ChatSessionEntity.updatedAt, order: .reverse)
    private var sessions: [ChatSessionEntity]

    @Environment(\.modelContext) private var modelContext

    let onSelectSession: (ChatSessionEntity) -> Void
    let onNewChat: () -> Void
    let onOpenSettings: () -> Void
    // Reports which session was just deleted, so the parent can swap the active
    // chat if the deleted one is currently on screen.
    var onDeleteSession: ((ChatSessionEntity) -> Void)? = nil

    @State private var searchQuery = ""
    @State private var searchExpanded = false
    @FocusState private var searchFieldFocused: Bool

    private var filtered: [ChatSessionEntity] {
        let base: [ChatSessionEntity]
        if searchQuery.isEmpty {
            base = sessions
        } else {
            let q = searchQuery.lowercased()
            base = sessions.filter {
                $0.title.lowercased().contains(q) || $0.preview.lowercased().contains(q)
            }
        }
        return base.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    // MARK: - Body
    // Everything sits in one VStack (normal flow). Collapsed, the search icon
    // rides on the header row next to "RoleIQ". Expanded, the field drops in
    // BELOW the header and the list starts under it — so search never overlaps
    // the rows (the old floating overlay is gone). The gear is the only pinned
    // element, bottom-right.

    var body: some View {
        ZStack {
            // Solid black panel. (Material here renders white in light mode and
            // washes the whole drawer out — glass stays on the icons only.)
            Color.black
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                if searchExpanded {
                    searchField
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if filtered.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }

            bottomBar
        }
    }

    // MARK: - Header (title + collapsed search icon)

    private var header: some View {
        HStack {
            Text("RoleEase")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            if !searchExpanded {
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        searchExpanded = true
                    }
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .neutralGlass(in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Expanded search field (in flow, pushes list down)

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            TextField("", text: $searchQuery,
                      prompt: Text("Search").foregroundColor(.white.opacity(0.45)))
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($searchFieldFocused)

            Button {
                Haptics.tap()
                searchQuery = ""
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    searchExpanded = false
                }
                searchFieldFocused = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .neutralGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Recents list (neutral rows)

    private var sessionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recents")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 2)

                ForEach(filtered) { session in
                    SidebarSessionRow(session: session) {
                        Haptics.tap()
                        onSelectSession(session)
                    } onDelete: {
                        Haptics.error()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            deleteSession(session)
                        }
                    } onTogglePin: {
                        Haptics.medium()
                        session.pinned.toggle()
                        try? modelContext.save()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(searchQuery.isEmpty ? "No conversations yet" : "No results")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom bar: Settings gear only, pinned bottom-right.
    // The "New Chat" button was removed — it duplicated the top-bar new-chat
    // button in ChatView. Settings stays here as the sidebar's gear entry.

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { Haptics.tap(); onOpenSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .neutralGlass(in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - SwiftData

    private func deleteSession(_ session: ChatSessionEntity) {
        onDeleteSession?(session)   // tell the parent BEFORE the object is gone
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - Neutral glass
// Dark, untinted glass for the sidebar's controls. No violet cast (unlike
// ChatView's tinted glassBackground), so on the black panel the search field
// and icon circles read as clean dark glass rather than grey-violet blocks.

private extension View {
    @ViewBuilder
    func neutralGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(Color.white.opacity(0.08), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }
}

// MARK: - Neutral text row

private struct SidebarSessionRow: View {
    let session: ChatSessionEntity
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if session.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(session.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onTogglePin) {
                Label(session.pinned ? "Unpin" : "Pin", systemImage: session.pinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: ChatSessionEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let samples = ["Evaluate Remote Contract Job", "Zillow Salary Comparison", "Infosys Internship Resume"]
    for title in samples {
        let s = ChatSessionEntity(title: title, mode: .general)
        container.mainContext.insert(s)
    }
    return ChatHistorySidebar(
        onSelectSession: { _ in },
        onNewChat: {},
        onOpenSettings: {}
    )
    .modelContainer(container)
}
