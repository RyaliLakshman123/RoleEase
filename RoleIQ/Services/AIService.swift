//
//  AIService.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import Combine

// MARK: - Backend Configuration
// ⚠️  Replace BASE_URL with your Render deployment URL
// e.g. "https://your-app-name.onrender.com"
private enum Backend {
    static let baseURL = "https://YOUR_RENDER_URL_HERE.onrender.com"

    static var chatURL: URL {
        URL(string: "\(baseURL)/api/chat")!
    }
}

// MARK: - AIService
// Mirrors EchoAIService but:
//  • Hits your Render backend instead of calling APIs directly
//  • SSE streaming via URLSession.dataTask reading text/event-stream
//  • Model switch: free → isPro=false (Gemini Flash), pro → isPro=true (Groq 70B)
//  • Carries CareerMode so the backend can select the right system prompt

@MainActor
final class AIService: ObservableObject {

    // ── Published state ──────────────────────────────────────────────────────
    @Published var messages:      [RoleIQMessage] = []
    @Published var selectedModel: RoleIQModel     = .free
    @Published var currentMode:   CareerMode      = .general
    @Published var isLoading:     Bool            = false

    // ── Internal ─────────────────────────────────────────────────────────────
    private var streamTask: URLSessionDataTask?
    private var streamBuffer = ""

    // ── Persistence hook (set by ChatHistoryViewModel) ───────────────────────
    var onSessionComplete: (([RoleIQMessage], CareerMode) -> Void)?

    // MARK: - Public API

    /// Send a user message and stream the AI reply.
    func send(_ text: String, model: RoleIQModel? = nil, mode: CareerMode? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let activeModel = model ?? selectedModel
        let activeMode  = mode  ?? currentMode

        selectedModel = activeModel
        currentMode   = activeMode

        // 1. Append user message
        let userMsg = RoleIQMessage(
            content:   trimmed,
            isUser:    true,
            modelUsed: activeModel.displayName,
            mode:      activeMode
        )
        messages.append(userMsg)

        // 2. Append streaming placeholder
        let placeholder = RoleIQMessage(
            content:     "",
            isUser:      false,
            modelUsed:   activeModel.displayName,
            mode:        activeMode,
            isStreaming: true
        )
        messages.append(placeholder)

        isLoading = true
        streamBuffer = ""

        Task { await startStream(model: activeModel, mode: activeMode) }
    }

    /// Load a saved session back into the message list (from ChatHistoryView)
    func loadSession(_ session: RoleIQChatSession) {
        messages     = session.messages
        currentMode  = session.mode
        isLoading    = false
        objectWillChange.send()
    }

    /// Clear current conversation
    func clear() {
        streamTask?.cancel()
        messages  = []
        isLoading = false
        objectWillChange.send()
    }

    // MARK: - SSE Streaming

    private func startStream(model: RoleIQModel, mode: CareerMode) async {
        // Build wire-format messages array (role/content pairs)
        // Exclude the empty streaming placeholder (last message)
        let wireMessages = messages
            .dropLast()                      // remove placeholder
            .filter { !$0.isStreaming }
            .map { $0.wireMessage }

        // Request body — matches exactly what Echo's /api/chat expects
        let body: [String: Any] = [
            "messages": wireMessages,
            "mode":     mode.rawValue,
            "isPro":    model.isPro
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            handleError("Failed to encode request", model: model, mode: mode)
            return
        }

        var request         = URLRequest(url: Backend.chatURL)
        request.httpMethod  = "POST"
        request.httpBody    = data
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream",      forHTTPHeaderField: "Accept")
        request.setValue("no-cache",               forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 60

        // URLSession stream reader
        await withCheckedContinuation { continuation in
            var resumed = false

            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self else { return }

                if let error {
                    Task { @MainActor in
                        self.handleError(error.localizedDescription, model: model, mode: mode)
                    }
                    if !resumed { resumed = true; continuation.resume() }
                    return
                }

                guard let data, let raw = String(data: data, encoding: .utf8) else {
                    Task { @MainActor in
                        self.handleError("Empty response from server", model: model, mode: mode)
                    }
                    if !resumed { resumed = true; continuation.resume() }
                    return
                }

                // Parse SSE lines
                Task { @MainActor in
                    self.parseSSE(raw, model: model, mode: mode)
                }

                if !resumed { resumed = true; continuation.resume() }
            }

            streamTask = task
            task.resume()
        }
    }

    // MARK: - SSE Parser

    /// Parses `data: {json}\n\n` stream exactly as the Echo backend sends it.
    private func parseSSE(_ raw: String, model: RoleIQModel, mode: CareerMode) {
        streamBuffer += raw
        let lines = streamBuffer.components(separatedBy: "\n")

        // Keep last incomplete line in buffer
        streamBuffer = lines.last ?? ""

        var accumulatedContent = ""

        for line in lines.dropLast() {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

            if payload == "[DONE]" {
                finalizeStream(model: model, mode: mode)
                return
            }

            guard
                let jsonData = payload.data(using: .utf8),
                let json     = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            // Error chunk from backend
            if let errMsg = json["error"] as? String {
                handleError(errMsg, model: model, mode: mode)
                return
            }

            if let chunk = json["content"] as? String {
                accumulatedContent += chunk
            }
        }

        // Append accumulated chunks to streaming placeholder
        if !accumulatedContent.isEmpty {
            appendToStream(accumulatedContent)
        }
    }

    // MARK: - Stream helpers

    private func appendToStream(_ chunk: String) {
        guard !messages.isEmpty else { return }
        let i = messages.count - 1
        guard messages[i].isStreaming else { return }

        messages[i] = RoleIQMessage(
            id:          messages[i].id,
            content:     messages[i].content + chunk,
            isUser:      false,
            timestamp:   messages[i].timestamp,
            modelUsed:   messages[i].modelUsed,
            mode:        messages[i].mode,
            isStreaming: true
        )
    }

    private func finalizeStream(model: RoleIQModel, mode: CareerMode) {
        guard !messages.isEmpty else { return }
        let i = messages.count - 1
        guard messages[i].isStreaming else { return }

        messages[i] = RoleIQMessage(
            id:          messages[i].id,
            content:     messages[i].content,
            isUser:      false,
            timestamp:   messages[i].timestamp,
            modelUsed:   model.displayName,
            mode:        mode,
            isStreaming: false
        )
        isLoading = false

        // Notify ChatHistoryViewModel to persist this session
        onSessionComplete?(messages, mode)
    }

    private func handleError(_ message: String, model: RoleIQModel, mode: CareerMode) {
        isLoading = false

        // Remove streaming placeholder if present
        if messages.last?.isStreaming == true {
            messages.removeLast()
        }

        messages.append(RoleIQMessage(
            content:   "⚠️ \(message)",
            isUser:    false,
            modelUsed: model.displayName,
            mode:      mode
        ))
    }
}
