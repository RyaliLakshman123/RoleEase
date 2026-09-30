//
//  ChatHistoryViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import Combine

// MARK: - ChatHistoryViewModel
// Mirrors Echo AI's SharedChatHistoryViewModel exactly:
//  • Singleton (shared instance used by AIService + ChatHistoryView)
//  • Persists sessions to UserDefaults as JSON
//  • Insert-at-front so newest session is always first
//  • Wired to AIService.onSessionComplete — auto-saves after every AI reply

final class ChatHistoryViewModel: ObservableObject {

    // ── Singleton ─────────────────────────────────────────────────────────────
    static let shared = ChatHistoryViewModel()

    // ── Published ─────────────────────────────────────────────────────────────
    @Published private(set) var sessions: [RoleIQChatSession] = []

    // ── Storage ───────────────────────────────────────────────────────────────
    private let defaults  = UserDefaults.standard
    private let storageKey = "RoleIQ_chat_sessions_v1"

    // ── Init ──────────────────────────────────────────────────────────────────
    private init() {
        load()
    }

    // MARK: - Public API

    /// Called by AIService.onSessionComplete after every completed stream.
    /// Replaces the most recent session for the same conversation thread
    /// (matched by first user message) so history doesn't duplicate on every reply.
    func upsertSession(messages: [RoleIQMessage], mode: CareerMode) {
        guard !messages.isEmpty else { return }

        let session = RoleIQChatSession(messages: messages, mode: mode)

        // If the first user message matches an existing session, replace it
        let firstUserContent = messages.first(where: { $0.isUser })?.content ?? ""
        if let idx = sessions.firstIndex(where: {
            ($0.messages.first(where: { $0.isUser })?.content ?? "") == firstUserContent
        }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }

        save()
    }

    /// Explicit save — call when user manually ends a conversation.
    func saveSession(messages: [RoleIQMessage], mode: CareerMode) {
        guard !messages.isEmpty else { return }
        let session = RoleIQChatSession(messages: messages, mode: mode)
        sessions.insert(session, at: 0)
        save()
    }

    func deleteSession(_ session: RoleIQChatSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func deleteAll() {
        sessions.removeAll()
        save()
    }

    // MARK: - Filtering helpers (for search / filter UI)

    func sessions(for mode: CareerMode) -> [RoleIQChatSession] {
        sessions.filter { $0.mode == mode }
    }

    func sessions(matching query: String) -> [RoleIQChatSession] {
        guard !query.isEmpty else { return sessions }
        let q = query.lowercased()
        return sessions.filter {
            $0.title.lowercased().contains(q) || $0.preview.lowercased().contains(q)
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data     = defaults.data(forKey: storageKey),
            let sessions = try? JSONDecoder().decode([RoleIQChatSession].self, from: data)
        else { return }
        self.sessions = sessions
    }
}

// MARK: - AIService wiring extension
// Call this once in your App entry point or where AIService is created:
//   AIService.shared.wireHistory()
// This connects the stream completion callback → auto-save.

extension AIService {
    func wireHistory() {
        onSessionComplete = { messages, mode in
            ChatHistoryViewModel.shared.upsertSession(messages: messages, mode: mode)
        }
    }
}
