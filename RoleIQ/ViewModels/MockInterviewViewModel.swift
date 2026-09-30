//
//  MockInterviewViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 17/08/26.
//


//
//  Owns one mock-interview session end to end:
//    JD input -> generated questions -> per-question transcript + on-device
//    speech metrics -> final summary (Gemini content feedback + local delivery).
//
//  Content feedback (strengths/improvements/overall) comes from the backend
//  via MockInterviewService. Delivery metrics (WPM, filler count, duration,
//  word count) are computed HERE on-device — the backend never sees audio.
//
//  Timing note: SpeechManager exposes transcript/isRecording/level but no
//  timestamps, so this VM stamps answer start/stop itself (see markAnswerStarted
//  / recordAnswer) rather than modifying SpeechManager.
//
//  Persistence: when a session finishes, we save a SessionSummary blob into an
//  InterviewSessionEntity (SwiftData). The view injects a ModelContext via
//  attach(context:) so this VM stays UI-agnostic. Metric types below are
//  Codable so the whole SessionSummary encodes as one JSON blob.
//
//  Structured so a future "Vibe Check" screen can extend the summary without a
//  rebuild: the per-answer metric and combined-result types are the seam.
//

import Foundation
import Observation
import SwiftData

// MARK: - Local (on-device) delivery metrics

/// Speaking metrics for a single answer, computed locally from the transcript
/// and the measured answer duration. No content judgement here.
struct SpeechMetrics: Codable, Equatable {
    let wordCount: Int
    let fillerCount: Int
    let durationSeconds: Double

    /// Words per minute. 0 when the answer had no measurable duration.
    var wordsPerMinute: Int {
        guard durationSeconds > 0 else { return 0 }
        return Int((Double(wordCount) / durationSeconds) * 60.0)
    }

    static let zero = SpeechMetrics(wordCount: 0, fillerCount: 0, durationSeconds: 0)
}

/// Everything captured for one question during the session.
struct AnswerRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let question: String
    var answer: String
    var metrics: SpeechMetrics
}

/// The finished session summary. Combines backend content feedback with the
/// locally-computed delivery metrics. This is the type a future Vibe Check
/// screen would read from / extend.
struct SessionSummary: Codable, Equatable {
    let content: [MockInterviewFeedback]   // per-question strengths/improvements
    let overall: String                    // backend overall readiness note
    let answers: [AnswerRecord]            // per-question local metrics + text
    let modelUsed: String

    // Aggregate delivery figures across the whole session, for the summary header.
    var averageWPM: Int {
        let spoken = answers.filter { $0.metrics.durationSeconds > 0 }
        guard !spoken.isEmpty else { return 0 }
        return spoken.map { $0.metrics.wordsPerMinute }.reduce(0, +) / spoken.count
    }

    var totalFillerWords: Int {
        answers.map { $0.metrics.fillerCount }.reduce(0, +)
    }

    var totalDurationSeconds: Double {
        answers.map { $0.metrics.durationSeconds }.reduce(0, +)
    }
}

// MARK: - Phase

enum InterviewPhase: Equatable {
    case setup          // pasting the JD
    case loadingQuestions
    case inProgress     // answering questions one at a time
    case evaluating     // waiting on /evaluate
    case summary        // showing the final summary
    case limitReached   // distinct from .failed so the UI can auto-trigger the paywall
    case failed(String) // user-facing error message
}

// MARK: - ViewModel

@MainActor
@Observable
final class MockInterviewViewModel {

    // MARK: Inputs / session config

    var jobDescription: String = ""
    /// Optional resume text (pull from the stored ResumeItem before starting).
    var resumeText: String? = nil
    /// Whether this session runs on the Pro (Gemini) path. Held here so the
    /// service stays a plain networking layer; wire the real source in Step 3.
    var isPro: Bool = false

    // MARK: Session state

    private(set) var phase: InterviewPhase = .setup
    private(set) var questions: [String] = []
    private(set) var currentIndex: Int = 0
    private(set) var answers: [AnswerRecord] = []
    private(set) var summary: SessionSummary?

    private let service = MockInterviewService.shared

    // Injected by the view so we can persist a finished session. Kept optional
    // and weakly-typed to SwiftData so the VM is still usable in previews/tests
    // without a container.
    private var modelContext: ModelContext?

    // Timing: stamped when the user starts speaking an answer.
    private var answerStartedAt: Date?

    // Common English filler words/phrases, matched case-insensitively on word
    // boundaries. "you know" / "sort of" / "kind of" are multi-word, handled below.
    private static let fillerWords: Set<String> = [
        "um", "uh", "er", "erm", "hmm", "like", "actually", "basically",
        "literally", "honestly", "right", "so", "well", "okay", "ok"
    ]
    private static let fillerPhrases: [String] = [
        "you know", "sort of", "kind of", "i mean", "i guess"
    ]

    // MARK: Derived UI helpers

    var currentQuestion: String? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }
    var questionNumber: Int { currentIndex + 1 }
    var totalQuestions: Int { questions.count }
    var isLastQuestion: Bool { currentIndex >= questions.count - 1 }

    // MARK: - Context injection

    /// Called once by the view (onAppear) so finished sessions can be saved.
    func attach(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Flow: start

    /// Fetch tailored questions for the pasted JD and move into the interview.
    func startSession() async {
        let jd = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jd.isEmpty else {
            phase = .failed("Paste a job description to begin.")
            return
        }

        if !isPro, MockInterviewLimit.hasReachedLimit {
            phase = .limitReached
            return
        }

        phase = .loadingQuestions
        do {
            let qs = try await service.generateQuestions(
                jobDescription: jd,
                resumeText: resumeText,
                isPro: isPro
            )
            questions = qs
            currentIndex = 0
            answers = []
            summary = nil
            phase = .inProgress
            if !isPro { MockInterviewLimit.increment() }
        } catch {
            phase = .failed((error as? MockInterviewError)?.errorDescription
                            ?? "Couldn't generate questions. Please try again.")
        }
    }

    /// Pre-fill a JD and jump to setup — used by "Redo this JD" from a saved
    /// summary. Leaves the user on the JD-entry screen so they can tweak/start.
    func prepareRedo(jobDescription jd: String) {
        reset()
        jobDescription = jd
    }

    // MARK: - Flow: answering

    /// Call when recording for the current answer begins — starts the clock.
    func markAnswerStarted() {
        answerStartedAt = Date()
    }

    /// Record the finished answer for the current question and compute its
    /// on-device metrics. Uses the clock started in markAnswerStarted(); if that
    /// wasn't called, duration is 0 and WPM reports 0 rather than a wild number.
    func recordAnswer(_ transcript: String) {
        guard let question = currentQuestion else { return }

        let duration = answerStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        answerStartedAt = nil

        let metrics = Self.computeMetrics(transcript: transcript, duration: duration)
        let record = AnswerRecord(
            question: question,
            answer: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            metrics: metrics
        )

        if let existing = answers.firstIndex(where: { $0.question == question }) {
            answers[existing] = record          // re-answered same question
        } else {
            answers.append(record)
        }
    }

    /// Advance to the next question. Returns false if there is no next question
    /// (caller should then finish the session).
    @discardableResult
    func advance() -> Bool {
        guard !isLastQuestion else { return false }
        currentIndex += 1
        return true
    }

    // MARK: - Flow: finish

    /// Send the full transcript for content evaluation and build the summary.
    func finishSession() async {
        phase = .evaluating

        let jd = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let turns = answers.map { MockInterviewTurn(question: $0.question, answer: $0.answer) }

        do {
            let evaluation = try await service.evaluate(
                transcript: turns,
                jobDescription: jd,
                isPro: isPro
            )
            let built = SessionSummary(
                content: evaluation.feedback,
                overall: evaluation.overall,
                answers: answers,
                modelUsed: evaluation.modelUsed
            )
            summary = built
            persistFinished(summary: built, jobDescription: jd)
            phase = .summary
        } catch {
            phase = .failed((error as? MockInterviewError)?.errorDescription
                            ?? "Couldn't evaluate your answers. Please try again.")
        }
    }

    /// Save the finished session to SwiftData. No-op if no context is attached
    /// (previews) or if there were no answered questions at all.
    private func persistFinished(summary: SessionSummary, jobDescription jd: String) {
        guard let modelContext else { return }
        guard summary.answers.contains(where: { !$0.answer.isEmpty }) else { return }

        let entity = InterviewSessionEntity(summary: summary, jobDescription: jd)
        modelContext.insert(entity)
        try? modelContext.save()
    }

    /// Reset everything back to the JD-entry screen for a fresh session.
    func reset() {
        phase = .setup
        questions = []
        currentIndex = 0
        answers = []
        summary = nil
        answerStartedAt = nil
    }

    // MARK: - Metrics (on-device)

    static func computeMetrics(transcript: String, duration: Double) -> SpeechMetrics {
        let lower = transcript.lowercased()

        // Tokenize into words on non-letter boundaries.
        let words = lower
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }

        let wordCount = words.count

        // Single-word fillers.
        var fillers = words.reduce(into: 0) { count, word in
            if fillerWords.contains(word) { count += 1 }
        }
        // Multi-word filler phrases — count non-overlapping occurrences.
        for phrase in fillerPhrases {
            fillers += lower.occurrences(of: phrase)
        }

        return SpeechMetrics(
            wordCount: wordCount,
            fillerCount: fillers,
            durationSeconds: max(0, duration)
        )
    }
}

// MARK: - Small helper

private extension String {
    /// Count non-overlapping occurrences of a substring.
    func occurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = startIndex..<endIndex
        while let found = range(of: needle, options: [], range: searchRange) {
            count += 1
            searchRange = found.upperBound..<endIndex
        }
        return count
    }
}
