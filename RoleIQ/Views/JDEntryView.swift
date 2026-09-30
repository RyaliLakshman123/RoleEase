//
//  JDEntryView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 17/08/26.
//


//  Step-1 of a mock interview: the candidate pastes the job description, taps
//  Start, and we hand off to MockInterviewViewModel.startSession(). This view
//  is intentionally dumb — it only edits `jobDescription` on the shared VM and
//  calls start. Phase transitions (loading -> orb) are driven by the VM and
//  handled by MockInterviewView.
//
//  This screen is ALSO the home for interview history. Past finished sessions
//  (InterviewSessionEntity) appear below the JD editor when any exist; tapping
//  one opens its saved summary read-only, with a "Redo this JD" action that
//  pre-fills the editor and starts a fresh session on the same role.


import SwiftUI
import SwiftData

struct JDEntryView: View {
    // Shared session VM owned by MockInterviewView.
    @Bindable var viewModel: MockInterviewViewModel

    /// Called when the user taps Start with a non-empty JD.
    var onOpenProfile: (() -> Void)? = nil
    /// Called when the user taps Start with a non-empty JD.
    let onStart: () -> Void
    
    // Most-recent finished interviews first.
    @Query(sort: \InterviewSessionEntity.createdAt, order: .reverse)
    private var pastSessions: [InterviewSessionEntity]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var editorFocused: Bool

    // The past session currently open in the read-only summary sheet.
    @State private var openedSession: InterviewSessionEntity?

    // Flips true on appear to drive the staggered entrance animation.
    @State private var appeared = false

    private let accent = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

    private var canStart: Bool {
        !viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isLoading: Bool {
        viewModel.phase == .loadingQuestions
    }

    // Drives the hero's headline copy: onboarding tone for first-timers,
    // welcome-back tone once they have past interviews.
    private var isFirstTime: Bool { pastSessions.isEmpty }

    /// Time-aware greeting, matching the ChatView empty-state pattern.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                topGlow

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        hero
                            .frame(maxWidth: .infinity)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        editor
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        if viewModel.phase == .limitReached {
                            Button { Haptics.medium(); onOpenProfile?() } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.30))
                                    Text("You've used this week's free interview — upgrade for unlimited")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .glassBackground(in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        } else if case .failed(let message) = viewModel.phase {
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
                                .transition(.opacity)
                        }

                        startButton
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        if pastSessions.isEmpty {
                            whatToExpect
                                .padding(.top, 8)
                        } else {
                            pastInterviewsSection
                                .padding(.top, 8)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Mock Interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: canStart)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { editorFocused = false }
        .sheet(item: $openedSession) { session in
            pastSummarySheet(for: session)
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.5).delay(0.05)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Header pieces

    // First-timers only: centered waveform disc + greeting + headline + blurb.
    private var hero: some View {
        VStack(spacing: 18) {
            WaveformDisc(accent: accent, reduceMotion: reduceMotion)

            VStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.9))

                Text(isFirstTime ? "Let's get you\ninterview-ready" : "Ready for\nanother round?")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(isFirstTime
                     ? "Paste a role below and RoleEase builds questions tailored to it."
                     : "Paste a new role, or revisit a past interview below.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .padding(.top, 4)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            editorFocused
                            ? Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.7)
                            : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )

            if viewModel.jobDescription.isEmpty {
                Text("e.g. iOS Engineer at Acme. Responsibilities include…")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $viewModel.jobDescription)
                .focused($editorFocused)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
        .frame(minHeight: 220, maxHeight: 340)
        .animation(.easeInOut(duration: 0.2), value: editorFocused)
    }

    private var startButton: some View {
        Button(action: {
            editorFocused = false
            onStart()
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                    Text("Generating questions…")
                } else {
                    Text("Start interview")
                    Image(systemName: "arrow.right")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canStart ? accent : Color.white.opacity(0.12))
            )
            // Soft violet lift on the CTA when it's actionable.
            .shadow(
                color: canStart ? accent.opacity(0.45) : .clear,
                radius: 18, x: 0, y: 6
            )
        }
        .disabled(!canStart || isLoading)
        .animation(.easeInOut(duration: 0.2), value: canStart)
    }

    // MARK: - Past interviews

    private var pastInterviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAST INTERVIEWS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))

            ForEach(pastSessions) { session in
                pastRow(session)
            }
        }
    }

    private func pastRow(_ session: InterviewSessionEntity) -> some View {
        Button {
            Haptics.tap()
            openedSession = session
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent.opacity(0.15)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(session.timeAgo)
                        if let s = session.summary {
                            Text("·")
                            Text("\(s.answers.count) Q")
                            if s.averageWPM > 0 {
                                Text("·")
                                Text("\(s.averageWPM) wpm")
                            }
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Haptics.error()
                delete(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Read-only summary sheet (past session)

    @ViewBuilder
    private func pastSummarySheet(for session: InterviewSessionEntity) -> some View {
        if let summary = session.summary {
            MockInterviewSummaryView(
                summary: summary,
                onRestart: {
                    let jd = session.jobDescription
                    openedSession = nil
                    if !viewModel.isPro, MockInterviewLimit.hasReachedLimit {
                        onOpenProfile?()
                    } else {
                        viewModel.prepareRedo(jobDescription: jd)
                    }
                },
                onDone: { openedSession = nil },
                restartLabel: "Redo this JD",
                showsCloseButton: true
            )
        } else {
            // Corrupt/empty blob — shouldn't happen, but never crash.
            VStack(spacing: 12) {
                Text("This summary couldn't be loaded.")
                    .foregroundStyle(.white.opacity(0.8))
                Button("Close") { openedSession = nil }
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
    }

    // Shown only to first-timers (no history yet), so the screen doesn't feel
    // bare before any interviews exist. Disappears once pastInterviewsSection
    // takes over that space. Rows fade/slide in with a per-row delay.
    private var whatToExpect: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW IT WORKS")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 4)

            expectRow(icon: "text.viewfinder", title: "Tailored questions",
                      detail: "Generated from the role you paste.", index: 0)
            expectRow(icon: "mic.fill", title: "Answer out loud",
                      detail: "Pace and clarity measured on-device.", index: 1)
            expectRow(icon: "chart.bar.doc.horizontal", title: "Get a breakdown",
                      detail: "Strengths, fixes, and delivery stats.", index: 2)
        }
    }

    private func expectRow(icon: String, title: String, detail: String, index: Int) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.16))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(
            reduceMotion ? nil
            : .easeOut(duration: 0.45).delay(0.25 + Double(index) * 0.08),
            value: appeared
        )
    }

    // MARK: - SwiftData

    private func delete(_ session: InterviewSessionEntity) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(session)
            try? modelContext.save()
        }
    }

    // MARK: - Background

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

    // Violet glow bleeding down from the top edge, behind the hero.
    private var topGlow: some View {
        RadialGradient(
            colors: [accent.opacity(0.35), accent.opacity(0)],
            center: .top, startRadius: 0, endRadius: 260
        )
        .frame(height: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Animated components

/// The centered hero disc: five violet bars rising and falling out of phase
/// inside a glass circle, with a glow halo that breathes. Reads as a calm,
/// living "listening" state. Honors Reduce Motion (static frame).
private struct WaveformDisc: View {
    let accent: Color
    let reduceMotion: Bool

    // Per-bar phase offsets and heights, tuned to match the mockup rhythm.
    private let barBaseHeights: [CGFloat] = [14, 26, 20, 30, 14]
    private let barPhases: [Double] = [0.0, 1.1, 0.5, 1.7, 2.3]
    private let barColors: [Color] = [
        Color(red: 0.65, green: 0.53, blue: 0.96),
        Color(red: 0.77, green: 0.69, blue: 0.98),
        Color(red: 0.545, green: 0.361, blue: 0.965),
        Color(red: 0.77, green: 0.69, blue: 0.98),
        Color(red: 0.65, green: 0.53, blue: 0.96)
    ]

    var body: some View {
        if reduceMotion {
            disc(glow: 0.85, scale: 1.0, heights: barBaseHeights)
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate

                // Halo breathing: slow eased sine.
                let raw = (sin(t * 1.05) + 1) / 2
                let breathe = raw * raw * (3 - 2 * raw)
                let glow = 0.7 + breathe * 0.3
                let scale = 0.96 + CGFloat(breathe) * 0.09

                // Each bar oscillates around its base height on its own phase.
                let heights = zip(barBaseHeights, barPhases).map { base, phase -> CGFloat in
                    let osc = sin(t * 3.0 + phase)          // faster than the halo
                    return base + CGFloat(osc) * 8
                }

                disc(glow: glow, scale: scale, heights: heights)
            }
        }
    }

    private func disc(glow: Double, scale: CGFloat, heights: [CGFloat]) -> some View {
        ZStack {
            // Breathing glow halo.
            Circle()
                .fill(accent.opacity(glow * 0.4))
                .frame(width: 124, height: 124)
                .blur(radius: 22)
                .scaleEffect(scale)

            // Glass disc.
            Circle()
                .fill(accent.opacity(0.14))
                .overlay(Circle().stroke(accent.opacity(0.55), lineWidth: 1))
                .frame(width: 96, height: 96)

            // Bars.
            HStack(alignment: .center, spacing: 5) {
                ForEach(heights.indices, id: \.self) { i in
                    Capsule()
                        .fill(barColors[i])
                        .frame(width: 4, height: max(6, heights[i]))
                }
            }
            .frame(height: 40)
        }
        .frame(width: 124, height: 124)
    }
}

// MARK: - Preview

#Preview("First-timer") {
    JDEntryView(viewModel: MockInterviewViewModel(), onStart: {})
        .modelContainer(for: InterviewSessionEntity.self, inMemory: true)
}
