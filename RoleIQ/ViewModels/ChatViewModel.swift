//
//  ChatViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 02/08/26.
//



//  Talks to POST https://RoleIQ-backend.onrender.com/api/chat and consumes
//  its SSE stream, appending tokens onto the in-flight assistant message.
//


import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: Published UI state

    @Published var model: RoleIQModel = .free          // display label only now (modelPill UI is commented out) — isPro sent to backend comes from isProUser, not this
    @Published var selectedMode: CareerMode = .general
    @Published var selectedTier: ModelTier = .light    // Light/Medium/Hard picker -> request body's "tier"
    @Published var messages: [RoleIQMessage] = []
    @Published var draftInput: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var isProUser: Bool = false              // real RevenueCat subscription status, set by ChatView from SubscriptionManager
    @Published var streamTick: Int = 0
    // Hidden attachment text. Set when the user attaches a file/photo; merged
    // into the outgoing message at send time and then cleared. Kept OUT of
    // draftInput so the extracted text never clutters the input field — the UI
    // shows only a small pill (attachmentLabel).
    @Published var attachmentText: String?
    @Published var attachmentLabel: String?
    @Published var didConfigure = false
    
    var hasAttachment: Bool { attachmentText?.isEmpty == false }

    // MARK: Private

    private let backendURL = URL(string: "https://RoleIQ-backend.onrender.com/api/chat")!
    private var streamTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var entity: ChatSessionEntity?
    private var insertedIntoContext = false
    
    // Light haptic tick per chunk while streaming, like ChatGPT's typing feel.
    // Throttled by character count so it doesn't buzz on every tiny token.
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private var charsSinceLastHaptic = 0
    private let hapticCharThreshold = 6

    // MARK: Setup

    func configure(context: ModelContext, entity: ChatSessionEntity) {
        self.modelContext = context
        self.entity = entity
        // An entity that already has messages is one loaded from history — it's
        // already persisted, so don't treat its first send as an insert.
        self.insertedIntoContext = !entity.messages.isEmpty
        self.messages = entity.messages
        self.selectedMode = entity.mode
        self.selectedTier = entity.mode.defaultTier
        self.didConfigure = true
    }

    // MARK: Attachments

    /// Store extracted text as a hidden attachment shown only as a pill.
    func attach(text: String, label: String) {
        attachmentText = text
        attachmentLabel = label
    }

    /// Remove the pending attachment without sending.
    func clearAttachment() {
        attachmentText = nil
        attachmentLabel = nil
    }

    // MARK: Sending

    func sendMessage() {
        let typed = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow sending when there's either typed text OR an attachment.
        guard (!typed.isEmpty || hasAttachment), !isStreaming else { return }
        // Free-tier daily cap. Pro is uncapped. Hard block — the input bar
        // shows the upgrade state (see ChatView) when this is true.
        if !isProUser, FreeMessageLimit.hasReachedLimit {
            Haptics.error()
            return
        }
        draftInput = ""
        errorMessage = nil

        // Build the message the model sees: hidden attachment text is merged in
        // here, at send time, then cleared. The visible bubble shows only what
        // the user typed (or a short attachment note if they typed nothing).
        let outgoing = composeOutgoing(typed: typed)
        let visible = composeVisible(typed: typed)
        clearAttachment()

        let userMessage = RoleIQMessage(content: outgoing, isUser: true, modelUsed: model.displayName, mode: selectedMode, displayContent: visible)
        messages.append(userMessage)

        let assistantMessage = RoleIQMessage(content: "", isUser: false, modelUsed: model.displayName, mode: selectedMode, isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        // Insert the draft into the context on first message only. Until now the
        // entity was held in memory (not persisted), so empty chats never appear
        // in history. This is the single point where a chat becomes "real".
        if let entity, let modelContext, !insertedIntoContext {
            modelContext.insert(entity)
            insertedIntoContext = true
        }

        persist()
        
        charsSinceLastHaptic = 0
        hapticGenerator.prepare()
        if !isProUser { FreeMessageLimit.increment() }
        streamTask?.cancel()
        streamTask = Task { await streamResponse(assistantIndex: assistantIndex) }
    }

    // What the model receives — typed text plus the hidden attachment block.
    private func composeOutgoing(typed: String) -> String {
        guard let text = attachmentText, !text.isEmpty else { return typed }
        let label = attachmentLabel ?? "attachment"
        let clipped = text.count > 12_000 ? String(text.prefix(12_000)) + "\n…(truncated)" : text
        let attachmentBlock = "[Attached: \(label)]\n\(clipped)"
        return typed.isEmpty ? attachmentBlock : "\(typed)\n\n\(attachmentBlock)"
    }

    // What the user sees in their own bubble — never the raw extracted text.
    private func composeVisible(typed: String) -> String {
        if hasAttachment {
            let label = attachmentLabel ?? "attachment"
            return typed.isEmpty ? "📎 \(label)" : "\(typed)\n\n📎 \(label)"
        }
        return typed
    }

    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
        clearStreamingFlagOnLastMessage()
        persist()
    }

    func copyMessage(_ message: RoleIQMessage) {
        UIPasteboard.general.string = Self.plainText(from: message.content)
    }

    func regenerate(messageID: UUID) {
        guard !isStreaming,
              let idx = messages.firstIndex(where: { $0.id == messageID }),
              !messages[idx].isUser,
              idx > 0, messages[idx - 1].isUser else { return }

        messages.removeSubrange(idx...)   // drop the old answer (and anything after it)

        let assistantMessage = RoleIQMessage(content: "", isUser: false, modelUsed: model.displayName, mode: selectedMode, isStreaming: true)
        messages.append(assistantMessage)
        streamTick &+= 1
        let assistantIndex = messages.count - 1

        persist()
        charsSinceLastHaptic = 0
        hapticGenerator.prepare()

        streamTask?.cancel()
        streamTask = Task { await streamResponse(assistantIndex: assistantIndex) }
    }

    func setFeedback(messageID: UUID, liked: Bool) {
        guard let idx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let m = messages[idx]
        messages[idx] = RoleIQMessage(
            id: m.id, content: m.content, isUser: m.isUser, timestamp: m.timestamp,
            modelUsed: m.modelUsed, mode: m.mode, isStreaming: m.isStreaming, liked: liked,
            displayContent: m.displayContent
        )
        persist()

        Task {
            var request = URLRequest(url: URL(string: "https://RoleIQ-backend.onrender.com/api/feedback")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["messageId": messageID.uuidString, "liked": liked])
            _ = try? await URLSession.shared.data(for: request)
        }
    }
    
    /// Strips markdown to clean plain text for copy/share, so pasted output
    /// never shows literal ** _ ` # characters. Rendering on-screen is
    /// unaffected — this only touches what leaves the app.
    static func plainText(from markdown: String) -> String {
        var s = markdown
        // Remove code fences but keep the code content.
        s = s.replacingOccurrences(of: "```", with: "")
        // Bold/italic/inline-code markers.
        for token in ["**", "__", "*", "_", "`"] {
            s = s.replacingOccurrences(of: token, with: "")
        }
        // Leading heading hashes and blockquote markers, line by line.
        s = s.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var l = String(line)
                while l.hasPrefix("#") { l.removeFirst() }
                if l.hasPrefix("> ") { l.removeFirst(2) }
                return l.trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
        return s
    }
    
    // MARK: Persistence

    private func persist() {
        entity?.mode = selectedMode
        entity?.messages = messages
        try? modelContext?.save()
    }

    // MARK: Mutating a value-type message array

    private func appendChunk(_ text: String, at index: Int, modelUsed: String? = nil) {
        guard messages.indices.contains(index) else { return }
        let m = messages[index]
        messages[index] = RoleIQMessage(
            id: m.id, content: m.content + text, isUser: m.isUser,
            timestamp: m.timestamp, modelUsed: modelUsed ?? m.modelUsed, mode: m.mode, isStreaming: true,
            displayContent: m.displayContent
        )
        streamTick &+= 1
        triggerStreamingHaptic(for: text)
    }

    private func triggerStreamingHaptic(for text: String) {
        guard Haptics.isEnabled else { return }   // respect the Settings toggle
        charsSinceLastHaptic += text.count
        guard charsSinceLastHaptic >= hapticCharThreshold else { return }
        charsSinceLastHaptic = 0
        hapticGenerator.impactOccurred(intensity: 0.4)
    }

    private func clearStreamingFlagOnLastMessage() {
        guard let lastIndex = messages.indices.last, messages[lastIndex].isStreaming else { return }
        let m = messages[lastIndex]
        messages[lastIndex] = RoleIQMessage(
            id: m.id, content: m.content, isUser: m.isUser,
            timestamp: m.timestamp, modelUsed: m.modelUsed, mode: m.mode, isStreaming: false,
            displayContent: m.displayContent
        )
        streamTick &+= 1
    }

        /// Loads a previously-sent USER message back into the input for editing.
        /// Removes that message and everything after it (its old answer no longer
        /// applies once the question changes), so the next send re-asks cleanly.
        /// The attachment, if the original had one, is NOT restored — the user is
        /// editing the typed text; they can re-attach if needed.
        func beginEditing(messageID: UUID) {
            guard !isStreaming,
                  let idx = messages.firstIndex(where: { $0.id == messageID }),
                  messages[idx].isUser else { return }

            // Put the editable text back in the field. Prefer the visible text
            // (what the user actually typed) over the raw outgoing content, so any
            // hidden "[Attached: …]" block or "📎 label" doesn't reappear as text.
            let editable = messages[idx].displayContent ?? messages[idx].content
            // Strip a trailing "📎 label" line if present (attachment marker).
            draftInput = stripAttachmentMarker(from: editable)

            // Remove this message and everything after it.
            messages.removeSubrange(idx...)
            persist()
            Haptics.tap()
        }

        /// Removes a trailing "📎 …" attachment marker line from visible text so it
        /// doesn't come back as literal text when editing.
        private func stripAttachmentMarker(from text: String) -> String {
            var lines = text.components(separatedBy: "\n")
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("📎") || last.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeLast()
            }
            return lines.joined(separator: "\n")
        }

  
    
    // MARK: SSE streaming

    private func streamResponse(assistantIndex: Int) async {
        isStreaming = true
        defer { isStreaming = false }

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Backend (routes/chat.js) reads: const { messages, mode, isPro, tier } = req.body;
        // It wants the FULL conversation as [{role, content}, ...] under "messages",
        // not a separate "message" + "history". "tier" is the user's Light/Medium/Hard
        // pick; the server falls back to its own mode-based default if this is omitted
        // or invalid, so this is safe to send alongside mode/isPro.
        let wireMessages = messages
            .filter { !$0.content.isEmpty }
            .suffix(20)
            .map { $0.wireMessage }

        let body: [String: Any] = [
            "messages": wireMessages,
            "isPro": isProUser,
            "mode": selectedMode.backendKey,
            "tier": selectedTier.rawValue
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("🔵 RoleIQ request -> isPro: \(isProUser), mode: \(selectedMode.backendKey), tier: \(selectedTier.rawValue)")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ChatNetworkError.server(status: http.statusCode)
            }

            errorMessage = nil   // connected successfully — clear any stale error
            
            for try await rawLine in bytes.lines {
                try Task.checkCancellation()

                guard rawLine.hasPrefix("data:") else { continue }
                let payload = rawLine.dropFirst(5).trimmingCharacters(in: .whitespaces)

                if payload == "[DONE]" { break }
                guard let data = payload.data(using: .utf8) else { continue }

                guard let chunk = try? JSONDecoder().decode(SSEChunk.self, from: data) else { continue }

                if let serverErr = chunk.error {
                    errorMessage = serverErr
                    continue
                }
                if let text = chunk.content, !text.isEmpty {
                    appendChunk(text, at: assistantIndex, modelUsed: model.displayName)
                }
            }
        } catch is CancellationError {
            // user tapped stop — keep whatever partial content streamed in
        } catch {
            Haptics.error()
            errorMessage = "Couldn't reach RolEase. Check your connection and try again."
            if messages.indices.contains(assistantIndex), messages[assistantIndex].content.isEmpty {
                let m = messages[assistantIndex]
                messages[assistantIndex] = RoleIQMessage(
                    id: m.id, content: "⚠️ Something went wrong generating a response.", isUser: false,
                    timestamp: m.timestamp, modelUsed: m.modelUsed, mode: m.mode, isStreaming: false,
                    displayContent: m.displayContent
                )
            }
        }

        clearStreamingFlagOnLastMessage()
        persist()
    }
}

// MARK: - SSE payload decoding
// Matches exactly what routes/chat.js sends:
//   res.write(`data: ${JSON.stringify({ content, modelUsed })}\n\n`)
// and on error: `data: ${JSON.stringify({ error: error.message })}\n\n`
private struct SSEChunk: Decodable {
    let content: String?
    let modelUsed: String?
    let error: String?
}

enum ChatNetworkError: LocalizedError {
    case server(status: Int)

    var errorDescription: String? {
        switch self {
        case .server(let status):
            return "Server returned status \(status)"
        }
    }
}
