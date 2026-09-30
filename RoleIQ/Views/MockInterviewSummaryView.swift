//
//  MockInterviewSummaryView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 17/08/26.
//


//
//  End-of-session summary. Two halves, exactly per the feature spec:
//    (a) CONTENT  — per-question strengths + improvements from the backend
//                   (Gemini, Groq fallback), judged against the JD.
//    (b) DELIVERY — pace (WPM), filler-word count, duration — all computed
//                   on-device in MockInterviewViewModel, never sent anywhere.
//
//  Structured so a future "Vibe Check" screen can slot in as a third section
//  without touching the interview flow: it would read the same SessionSummary
//  (and its per-answer AnswerRecord.metrics) that this view renders.
//


import SwiftUI

struct MockInterviewSummaryView: View {
    let summary: SessionSummary

    /// Start a brand-new session (returns to JD entry).
    let onRestart: () -> Void
    /// Dismiss the whole feature (e.g. back to dashboard).
    let onDone: () -> Void
    var restartLabel: String = "New interview"
    /// Shows a top-left X that calls onDone. On for the read-only past-summary
    /// sheet (which has no other way out); off for the live end-of-interview
    /// summary, where "Done" already handles dismissal.
    var showsCloseButton: Bool = false
    private let accent = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Drives the count-up: 0 → 1 progress the metric values interpolate against.
    @State private var countProgress: CGFloat = 0

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    deliverySection
                    contentSection

                    if !summary.overall.isEmpty {
                        overallSection
                    }

                    // Placeholder anchor for the future Vibe Check section.
                    // Intentionally empty for now — see feature spec.

                    actions
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        // iOS 26 Liquid Glass. .interactive() gives the press
                        // highlight; clipShape keeps the glass a clean circle.
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
            }
        }
        .onAppear {
            if reduceMotion {
                countProgress = 1
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.2)) {
                    countProgress = 1
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION SUMMARY")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))

            Text("Here's how you did")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    // MARK: - Delivery (on-device metrics)

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("DELIVERY")

            HStack(spacing: 12) {
                metricCard(
                    value: summary.averageWPM > 0
                        ? "\(animatedInt(to: summary.averageWPM))"
                        : "—",
                    unit: "wpm",
                    caption: "Avg pace",
                    descriptor: summary.averageWPM > 0 ? paceDescriptor(summary.averageWPM) : nil,
                    index: 0
                )
                metricCard(
                    value: "\(animatedInt(to: summary.totalFillerWords))",
                    unit: summary.totalFillerWords == 1 ? "word" : "words",
                    caption: "Filler",
                    descriptor: fillerDescriptor(summary.totalFillerWords),
                    index: 1
                )
                metricCard(
                    value: animatedDuration(to: summary.totalDurationSeconds),
                    unit: "",
                    caption: "Total time",
                    descriptor: answerCountDescriptor,
                    index: 2
                )
            }
        }
    }

    private func metricCard(
        value: String,
        unit: String,
        caption: String,
        descriptor: String?,
        index: Int
    ) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            if let descriptor {
                Text(descriptor)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(accent.opacity(0.14))
                    )
                    .opacity(countProgress >= 1 ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeIn(duration: 0.25).delay(1.0 + Double(index) * 0.08),
                        value: countProgress
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Count-up interpolation

    /// Interpolates an integer from 0 → target as countProgress animates 0 → 1.
    private func animatedInt(to target: Int) -> Int {
        Int((CGFloat(target) * countProgress).rounded())
    }

    /// Interpolates a duration and formats it, so the time counts up too.
    private func animatedDuration(to seconds: Double) -> String {
        durationText(seconds * Double(countProgress))
    }

    // MARK: - Neutral descriptors
    // Chosen so EVERY bucket reads as acceptable — never "too fast", "bad",
    // or a red zone. The goal is context, not judgment.

    private func paceDescriptor(_ wpm: Int) -> String {
        switch wpm {
        case ..<110:  return "Measured"
        case 110...160: return "Conversational"
        default:      return "Brisk"
        }
    }

    private func fillerDescriptor(_ count: Int) -> String {
        switch count {
        case 0:      return "Crisp"
        case 1...8:  return "Low"
        default:     return "Some"
        }
    }

    private var answerCountDescriptor: String {
        let n = summary.answers.count
        return n == 1 ? "1 answer" : "\(n) answers"
    }

    // MARK: - Content (backend feedback)

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("CONTENT")

            ForEach(Array(summary.content.enumerated()), id: \.element.id) { index, item in
                feedbackCard(index: index, item: item)
            }
        }
    }

    private func feedbackCard(index: Int, item: MockInterviewFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Q\(index + 1)  ·  \(item.question)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            feedbackRow(
                icon: "checkmark.circle.fill",
                tint: Color(red: 0.45, green: 0.85, blue: 0.55),
                label: "Strengths",
                text: item.strengths
            )
            feedbackRow(
                icon: "arrow.up.forward.circle.fill",
                tint: accent,
                label: "Improve",
                text: item.improvements
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func feedbackRow(icon: String, tint: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))
                Text(text.isEmpty ? "—" : text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Overall

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("OVERALL")
            Text(summary.overall)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accent.opacity(0.35), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onRestart) {
                Text(restartLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(accent)
                    )
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.4))
    }

    private func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private var backgroundLayer: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.55),
                .init(color: Color(red: 0.16, green: 0.06, blue: 0.26), location: 1.0)
            ]),
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}


#Preview {
    MockInterviewSummaryView(
        summary: SessionSummary(
            content: [
                MockInterviewFeedback(
                    question: "Tell me about a time you shipped under a tight deadline.",
                    strengths: "Clear STAR structure, and you named the concrete outcome (shipped two days early).",
                    improvements: "Tie it to this JD's focus on cross-team delivery — quantify who you coordinated with."
                ),
                MockInterviewFeedback(
                    question: "Why do you want this role?",
                    strengths: "Genuine enthusiasm came through and you referenced the product by name.",
                    improvements: "Connect your motivation to a specific responsibility listed in the JD, not the company broadly."
                )
            ],
            overall: "You're close to interview-ready for this role. Your examples are strong; the gap is tying each answer back to the specific JD requirements rather than speaking generally.",
            answers: [
                AnswerRecord(
                    question: "Tell me about a time you shipped under a tight deadline.",
                    answer: "Sample answer text…",
                    metrics: SpeechMetrics(wordCount: 210, fillerCount: 4, durationSeconds: 92)
                ),
                AnswerRecord(
                    question: "Why do you want this role?",
                    answer: "Sample answer text…",
                    metrics: SpeechMetrics(wordCount: 160, fillerCount: 3, durationSeconds: 68)
                )
            ],
            modelUsed: "gemini"
        ),
        onRestart: {},
        onDone: {}
    )
}
