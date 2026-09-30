//
//  MockInterviewService.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 17/08/26.
//


//
//  Talks to the two plain-JSON mock-interview routes on the Render backend:
//    POST /api/mock-interview/questions   (JD + optional resume -> [String])
//    POST /api/mock-interview/evaluate    (transcript + JD -> content feedback)
//
//  Networking skeleton (90s timeout, 429 handling, `error` parsing) mirrors
//  BackendService. Unlike ChatViewModel these routes are NOT SSE — they return
//  one JSON body — so we decode with JSONDecoder instead of reading a stream.
//  Render's free tier cold-starts (~50s), so each call gets ONE automatic retry.
//

import Foundation

// MARK: - Wire types (match mockInterview.js exactly)

/// One question/answer pair sent to /evaluate.
struct MockInterviewTurn: Codable {
    let question: String
    let answer: String
}

/// Per-question content feedback returned by /evaluate.
/// Shape: {"question", "strengths", "improvements"}
struct MockInterviewFeedback: Codable, Identifiable, Equatable {
    var id: String { question }
    let question: String
    let strengths: String
    let improvements: String
}

// Response envelopes -------------------------------------------------------

private struct QuestionsResponse: Decodable {
    let questions: [String]
    let modelUsed: String?
}

private struct EvaluateResponse: Decodable {
    let feedback: [MockInterviewFeedback]
    let overall: String?
    let modelUsed: String?
}

/// Decoded result of /evaluate (content only; delivery metrics are on-device).
struct MockInterviewEvaluation: Equatable {
    let feedback: [MockInterviewFeedback]
    let overall: String
    let modelUsed: String
}

// MARK: - Errors

enum MockInterviewError: LocalizedError {
    case badResponse
    case rateLimited
    case parsingFailed
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:      return "Couldn't reach RoleIQ. Check your connection and try again."
        case .rateLimited:      return "You're going a bit fast — give it a moment and try again."
        case .parsingFailed:    return "RoleIQ returned an unexpected response. Please try again."
        case .server(let msg):  return msg
        }
    }
}

// MARK: - Service

final class MockInterviewService {
    static let shared = MockInterviewService()
    private init() {}

    private let baseURL = "https://RoleIQ-backend.onrender.com"

    // Render free tier: ~17s once awake, ~50s cold. Match the app's 60–90s window.
    private let timeout: TimeInterval = 90

    // MARK: Public API

    /// Generate ~5 tailored questions from a job description and optional resume text.
    /// `tier` is intentionally omitted from the request — the backend picks
    /// getTier("interview") itself, so there's nothing to keep in sync here.
    func generateQuestions(
        jobDescription: String,
        resumeText: String? = nil,
        isPro: Bool
    ) async throws -> [String] {
        var body: [String: Any] = [
            "jobDescription": jobDescription,
            "isPro": isPro
        ]
        if let resumeText, !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["resumeText"] = resumeText
        }

        let data = try await post(path: "/api/mock-interview/questions", body: body)

        guard let decoded = try? JSONDecoder().decode(QuestionsResponse.self, from: data) else {
            throw MockInterviewError.parsingFailed
        }
        let questions = decoded.questions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !questions.isEmpty else { throw MockInterviewError.parsingFailed }
        return questions
    }

    /// Evaluate the full transcript against the JD. Content feedback only —
    /// pace / filler / duration are computed on-device in the ViewModel.
    func evaluate(
        transcript: [MockInterviewTurn],
        jobDescription: String,
        isPro: Bool
    ) async throws -> MockInterviewEvaluation {
        let body: [String: Any] = [
            "transcript": transcript.map { ["question": $0.question, "answer": $0.answer] },
            "jobDescription": jobDescription,
            "isPro": isPro
        ]

        let data = try await post(path: "/api/mock-interview/evaluate", body: body)

        guard let decoded = try? JSONDecoder().decode(EvaluateResponse.self, from: data) else {
            throw MockInterviewError.parsingFailed
        }
        return MockInterviewEvaluation(
            feedback: decoded.feedback,
            overall: decoded.overall ?? "",
            modelUsed: decoded.modelUsed ?? ""
        )
    }

    // MARK: - Networking core

    /// POST JSON and return the raw body. Retries ONCE on a cold-start-style
    /// failure (timeout / connection lost / cannot-connect), since Render's
    /// free tier can take ~50s to wake and the first hit sometimes dies.
    private func post(path: String, body: [String: Any]) async throws -> Data {
        do {
            return try await sendRequest(path: path, body: body)
        } catch {
            guard isColdStartFailure(error) else { throw error }
            // One retry — the instance is likely awake now.
            return try await sendRequest(path: path, body: body)
        }
    }

    private func sendRequest(path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw MockInterviewError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw MockInterviewError.badResponse
        }

        if http.statusCode == 429 {
            throw MockInterviewError.rateLimited
        }

        guard (200...299).contains(http.statusCode) else {
            // Backend errors come back as {"error": "..."} — surface that message.
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw MockInterviewError.server(message ?? "Server error (\(http.statusCode))")
        }

        return data
    }

    /// True for the transient network errors a cold Render instance produces,
    /// which are worth exactly one retry.
    private func isColdStartFailure(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        switch ns.code {
        case NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
