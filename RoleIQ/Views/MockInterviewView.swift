//
//  MockInterviewView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 03/08/26.
//



import SwiftUI
import SwiftData
import UIKit

struct MockInterviewView: View {
    // Not private: InterviewLiveMeters.swift (an extension in another file)
    // reads speech + recordingStartedAt to drive the live WPM / timer meters.
    @State var speech = SpeechManager()
    @State private var voice = VoiceSynthesizer()
    @State private var viewModel = MockInterviewViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    // Stamped when recording starts, cleared when it stops. Drives the live
    // answer timer and WPM in InterviewLiveMeters.
    @State var recordingStartedAt: Date?

    // Most-recent resume first, so we can pass its text to the backend when
    // starting a session. nil / empty is fine — the service omits it.
    @Query(sort: \ResumeItem.dateAdded, order: .reverse)
    private var resumes: [ResumeItem]

    // True once the user has stopped recording the current answer. Enables the
    // Next control and lets them re-record before advancing.
    @State private var hasAnsweredCurrent = false

    /// Called when the user ends the feature. RootView routes straight here, so
    /// the default is a no-op.
    var onClose: () -> Void = {}
    var onOpenProfile: (() -> Void)? = nil
    
    private var isThinking: Bool { viewModel.phase == .evaluating }
    private var isActive: Bool { speech.isRecording || voice.isSpeaking || isThinking }

    // Live 0...1 amplitude — real mic level while listening, gentle idle otherwise.
    private var audioLevel: CGFloat {
        speech.isRecording ? speech.level : 0
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup, .loadingQuestions, .failed, .limitReached:   // limitReached added
                        JDEntryView(viewModel: viewModel, onOpenProfile: onOpenProfile) {
                            viewModel.resumeText = resumes.first?.extractedText
                            Task { await viewModel.startSession() }
                        }

            case .inProgress, .evaluating:
                interviewScreen

            case .summary:
                if let summary = viewModel.summary {
                    MockInterviewSummaryView(
                        summary: summary,
                        onRestart: { restart() },
                        onDone: { restart() }
                    )
                }
            }
        }
        .onAppear {
            viewModel.attach(context: modelContext)
            viewModel.isPro = subscriptionManager.isProUser
        }
        .onChange(of: subscriptionManager.isProUser) { _, newValue in
            viewModel.isPro = newValue
        }
        .onChange(of: viewModel.phase) { _, newPhase in
                if newPhase == .limitReached {
                    onOpenProfile?()   // auto-present the paywall the moment the limit hits
            }
        }
    }

    // MARK: - Interview screen (orb)

    private var interviewScreen: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar
                Spacer()
                contentStack
                Spacer()
                liveMeters              // live WPM + timer, only while recording
                orb
                bottomControls
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .preferredColorScheme(.dark)
        .onAppear { speakCurrentQuestion() }
        .onChange(of: viewModel.currentIndex) { _, _ in speakCurrentQuestion() }
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

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            circleIcon("xmark") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                voice.stop()
                speech.stopRecording()
                restart()                 // back to the JD-entry screen
            }
            Spacer()
            // Right side intentionally empty — nothing should compete with the
            // orb for attention while the candidate is mid-answer.
        }
    }
    
    private func circleIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 52, height: 52)
                .background(Circle().fill(.white.opacity(0.08)))
        }
    }

    // MARK: - Content
    // The question appears ONCE, as the voice-synced reveal. While recording we
    // show a "Listening…" indicator and the live transcript instead.
    private var contentStack: some View {
        VStack(spacing: 18) {
            Text("QUESTION \(viewModel.questionNumber) OF \(viewModel.totalQuestions)")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))

            // The question, revealed word-by-word as the voice speaks it. Once
            // speech finishes, VoiceSynthesizer sets revealedText to the full
            // string, so the whole question stays on screen.
            Text(voice.revealedText.isEmpty ? (viewModel.currentQuestion ?? "") : voice.revealedText)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .animation(.easeIn(duration: 0.15), value: voice.revealedText)

            // Only a calm "Listening…" state while recording. The live transcript
            // is intentionally hidden: SFSpeechRecognizer mishears words mid-stream,
            // so raw partial text looks broken even though the saved answer is fine.
            // The words still feed the meters and the summary — they're just not shown.
            if speech.isRecording {
                listeningIndicator
            }

//            // Live transcript of the user's answer.
//            if !speech.transcript.isEmpty {
//                Text(speech.transcript)
//                    .font(.system(size: 15))
//                    .foregroundStyle(.white.opacity(0.6))
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 8)
//            } else if speech.isRecording {
//                Text("Start speaking your answer…")
//                    .font(.system(size: 14))
//                    .foregroundStyle(.white.opacity(0.35))
//            }
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.55, green: 0.35, blue: 1.0))
                .frame(width: 8, height: 8)
                .opacity(0.9)
            Text("Listening…")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Orb
    private var orb: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)

        return shape
            .fill(Color.black)
            .overlay(
                PillMaterial(state: orbState, level: audioLevel)
                    .clipShape(shape)
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.62, green: 0.35, blue: 1.0)
                                .opacity(isActive ? 0.8 : 0.30),
                            Color(red: 0.3, green: 0.1, blue: 0.6).opacity(0.15)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .frame(width: 158, height: 78)
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.5), value: isActive)
    }

    // MARK: - Bottom controls (context-aware)
    // Recording:  just the big Stop button (folds in your "X to stop" idea).
    // Idle:       Skip (left) · Mic (center) · End (right), plus a Next button
    //             above once the current answer has been recorded.
    private var bottomControls: some View {
        VStack(spacing: 18) {
            if hasAnsweredCurrent && !speech.isRecording {
                Button(action: advance) {
                    HStack(spacing: 8) {
                        Text(viewModel.isLastQuestion ? "Finish & see summary" : "Next question")
                        Image(systemName: viewModel.isLastQuestion ? "checkmark" : "arrow.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.545, green: 0.361, blue: 0.965)) // #8B5CF6
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if speech.isRecording {
                recordingControls
            } else {
                idleControls
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasAnsweredCurrent)
        .animation(.easeInOut(duration: 0.25), value: speech.isRecording)
    }

    // Only Stop while recording — nothing else to fumble.
    private var recordingControls: some View {
        VStack(spacing: 10) {
            Button(action: toggleRecording) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(
                        Circle().fill(Color(red: 0.55, green: 0.25, blue: 1.0).opacity(0.85))
                    )
            }
            Text("Tap to stop")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // Skip · Mic · End when idle.
    private var idleControls: some View {
        HStack {
            controlButton(
                icon: "forward.fill",
                label: "Skip",
                disabled: isThinking,
                action: skipQuestion
            )
            Spacer()
            micButton
            Spacer()
            controlButton(
                icon: "flag.checkered",
                label: "End",
                disabled: isThinking,
                action: endInterview
            )
        }
    }

    private var micButton: some View {
        VStack(spacing: 8) {
            Button(action: toggleRecording) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .overlay(
                        Circle().stroke(
                            Color(red: 0.62, green: 0.40, blue: 1.0).opacity(0.5),
                            lineWidth: 1.5
                        )
                    )
            }
            .disabled(isThinking)
            .opacity(isThinking ? 0.4 : 1.0)

            Text(hasAnsweredCurrent ? "Re-record" : "Answer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func controlButton(
        icon: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1.0)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var orbState: PillMaterial.State {
        if voice.isSpeaking { return .aiSpeaking }
        if speech.isRecording { return .listening }
        if isThinking { return .thinking }
        return .idle
    }

    // MARK: - Actions

    private func speakCurrentQuestion() {
        guard let question = viewModel.currentQuestion else { return }
        hasAnsweredCurrent = false
        speech.transcript = ""
        voice.speak(question)
    }

    private func toggleRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            if speech.isRecording {
                speech.stopRecording()
                recordingStartedAt = nil
                await handleAnswer(speech.transcript)
            } else if await speech.requestAuthorization() {
                voice.stop()
                viewModel.markAnswerStarted()   // start the clock for WPM
                recordingStartedAt = Date()
                try? speech.startRecording()
            }
        }
    }

    /// Records the answer + on-device metrics. No spoken reply — feedback is
    /// end-only. Does NOT auto-advance: the user can re-record, then taps Next.
    private func handleAnswer(_ userAnswer: String) async {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.recordAnswer(trimmed)
        hasAnsweredCurrent = true
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        goToNextOrFinish()
    }

    /// Skip the current question without recording an answer.
    private func skipQuestion() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        voice.stop()
        speech.transcript = ""
        recordingStartedAt = nil
        // Record an empty answer so the transcript/summary stay aligned with
        // the question list; the backend renders "(no answer given)".
        viewModel.markAnswerStarted()
        viewModel.recordAnswer("")
        goToNextOrFinish()
    }

    /// End the interview early and go straight to the summary.
    private func endInterview() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        voice.stop()
        Task { await viewModel.finishSession() }
    }

    private func goToNextOrFinish() {
        if viewModel.isLastQuestion {
            voice.stop()
            Task { await viewModel.finishSession() }
        } else {
            viewModel.advance()   // onChange(currentIndex) speaks the next question
        }
    }

    private func restart() {
        voice.stop()
        speech.transcript = ""
        recordingStartedAt = nil
        hasAnsweredCurrent = false
        viewModel.reset()
    }
}

// MARK: - Material that lives inside the pill
/// Bottom-anchored glow, clipped INSIDE the pill. A wide violet pool rising
/// from a white-hot lip, with a soft hotspot that drifts for life. Top of the
/// pill stays black. Matches the reference's low, wide, periwinkle→white band.
///
///   • idle       – dim, low, slow breathing
///   • aiSpeaking – bright, saturated, lifts higher, hotspot drifts faster
///   • listening  – reacts to live mic `level`
private struct PillMaterial: View {
    enum State { case idle, aiSpeaking, listening, thinking }
    var state: State
    var level: CGFloat   // 0...1 live audio amplitude

    private var accent: Color {
        switch state {
        case .idle:       return Color(red: 0.50, green: 0.34, blue: 1.0)
        case .aiSpeaking: return Color(red: 0.60, green: 0.40, blue: 1.0)
        case .listening:  return Color(red: 0.44, green: 0.30, blue: 1.0)
        case .thinking:   return Color(red: 0.54, green: 0.38, blue: 1.0)
        }
    }
    // Periwinkle mid-tone that sits between the violet body and the white lip.
    private var midTone: Color { Color(red: 0.62, green: 0.58, blue: 1.0) }
    private var lipColor: Color { Color(red: 0.90, green: 0.86, blue: 1.0) }
    private var isActive: Bool { state != .idle }

    // Shift a color's hue by `delta` (0…1 of the wheel) — used for a subtle,
    // living color drift so the violet breathes between blue-violet and magenta.
    private func hueShift(_ color: Color, _ delta: Double) -> Color {
        let ui = UIColor(color)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let newHue = (hue + CGFloat(delta)).truncatingRemainder(dividingBy: 1)
        return Color(hue: Double(newHue < 0 ? newHue + 1 : newHue),
                     saturation: Double(sat), brightness: Double(bri))
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let l = max(0, min(1, level))

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                let baseSpeed: Double = {
                    switch state {
                    case .idle:       return 0.5
                    case .aiSpeaking: return 1.8
                    case .listening:  return 1.2
                    case .thinking:   return 0.9
                    }
                }()
                let speed = baseSpeed + Double(l) * 1.2

                // Multiple out-of-phase waves for organic, non-repeating motion
                let wave1 = sin(t * speed * 0.7)
                let wave2 = sin(t * speed * 0.63 + 1.4)
                let wave3 = cos(t * speed * 0.9 + 0.6)
                let wave4 = sin(t * speed * 0.45 + 2.1)
                let wave5 = cos(t * speed * 1.23 + 3.4)   // faster micro-shimmer
                let wave6 = sin(t * speed * 0.33 + 0.9)   // slow deep sway

                let rawPulse = (wave2 + 1) / 2
                let breathe = rawPulse * rawPulse * (3 - 2 * rawPulse)

                // Iridescent hue cycle — the light slowly travels violet →
                // magenta → back toward cyan-violet and around. Range kept
                // anchored near violet so it stays classy, not rainbow.
                // Each layer samples the cycle at its own offset, so different
                // parts of the orb show different hues at once = depth.
                let cycle = t * (isActive ? 0.28 : 0.16)          // cycle speed
                let hueBase   = sin(cycle) * 0.10                  // body: ±0.10
                let hueMid    = sin(cycle + 1.6) * 0.13            // mid-band offset
                let hueHot    = sin(cycle + 3.0) * 0.10            // hotspot offset
                let hueEmber1 = sin(cycle + 0.8) * 0.14            // ember A
                let hueEmber2 = sin(cycle + 4.2) * 0.14            // ember B

                let liveAccent  = hueShift(accent,  hueBase)
                let liveMid     = hueShift(midTone, hueMid)
                let hotTint     = hueShift(midTone, hueHot)

                let energy: CGFloat = {
                    switch state {
                    case .idle:       return 0.25 + CGFloat(breathe) * 0.60
                    case .aiSpeaking: return max(CGFloat(breathe) * 0.7, l)
                    case .listening:  return max(CGFloat(breathe) * 0.30, l * 1.2)
                    case .thinking:   return 0.35 + CGFloat(breathe) * 0.35
                    }
                }()

                // How high the glow band rises from the bottom edge.
                let riseIdle: CGFloat = 0.42 + energy * 0.22
                let riseActive: CGFloat = 0.58 + energy * 0.30
                let rise = isActive ? riseActive : riseIdle
                let bandHeight = h * rise

                let bodyY = h - bandHeight * 0.32
                let lipY = h + 4

                let bodyOpacity = isActive
                    ? 0.72 + energy * 0.28
                    : 0.46 + CGFloat(breathe) * 0.26

                let lipEnergy: CGFloat = {
                    switch state {
                    case .idle:       return 0.40 + CGFloat(breathe) * 0.28
                    case .aiSpeaking: return 0.82 + energy * 0.18
                    case .listening:  return 0.52 + l * 0.42
                    case .thinking:   return 0.48 + CGFloat(breathe) * 0.30
                    }
                }()

                // Pool sways a little even at idle so there's always motion.
                let cx = w / 2 + CGFloat(wave1) * (isActive ? w * 0.03 : w * 0.05)
                // Hotspot drifts across the lip for life.
                let hotX = w / 2 + CGFloat(wave3) * w * (isActive ? 0.22 : 0.18)
                let hotIntensity = (0.5 + CGFloat(wave4) * 0.5) * lipEnergy

                ZStack {
                    // Deep near-black base
                    Rectangle()
                        .fill(Color(red: 0.022, green: 0.011, blue: 0.050))

                    // Wide violet body pool rising from the bottom
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    liveAccent.opacity(bodyOpacity),
                                    liveAccent.opacity(bodyOpacity * 0.5),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: bandHeight
                            )
                        )
                        .frame(width: w * 1.5, height: bandHeight * 2.0)
                        .position(x: cx, y: bodyY)
                        .blur(radius: isActive ? 22 : 16)

                    // Periwinkle mid-band just above the lip — the color bridge
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    liveMid.opacity(lipEnergy * 0.7),
                                    .clear
                                ],
                                center: .center, startRadius: 0, endRadius: w * 0.55
                            )
                        )
                        .frame(width: w * 1.2, height: h * 0.55)
                        .position(x: cx, y: h - h * 0.02)
                        .blur(radius: isActive ? 16 : 18)
                        .blendMode(.plusLighter)

                    // White-hot bottom lip — bright wide crescent along the base
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    lipColor.opacity(lipEnergy),
                                    lipColor.opacity(lipEnergy * 0.4),
                                    .clear
                                ],
                                center: .center, startRadius: 0, endRadius: w * 0.5
                            )
                        )
                        .frame(width: w * 1.15, height: h * 0.5)
                        .position(x: cx, y: lipY)
                        .blur(radius: state == .aiSpeaking ? 9 : 13)
                        .blendMode(.plusLighter)

                    // Drifting hot spot — the roaming bright point that gives life
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(hotIntensity * 0.6), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.26
                            )
                        )
                        .frame(width: w * 0.5, height: h * 0.32)
                        .position(x: hotX, y: lipY - h * 0.02)
                        .blur(radius: isActive ? 9 : 12)
                        .blendMode(.plusLighter)

                    // Second hotspot drifting the OTHER way — the two crossing
                    // gives the lip a shifting, liquid highlight.
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [hueShift(lipColor, hueHot * 0.6).opacity(hotIntensity * 0.45), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.18
                            )
                        )
                        .frame(width: w * 0.34, height: h * 0.24)
                        .position(
                            x: w / 2 - CGFloat(wave5) * w * (isActive ? 0.20 : 0.08),
                            y: lipY - h * 0.03 - CGFloat(breathe) * h * 0.03
                        )
                        .blur(radius: isActive ? 8 : 11)
                        .blendMode(.plusLighter)

                    // Rising ember wisps — two faint plumes lifting off the lip.
                    // Always present (softer at idle) so there's constant gentle
                    // vertical motion that draws the eye.
                    let emberScale: CGFloat = isActive ? 1.0 : 0.6
                    let emberRise = (CGFloat(breathe) * 0.5 + 0.5)
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [hueShift(midTone, hueEmber1).opacity(lipEnergy * 0.30 * emberScale), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.14
                            )
                        )
                        .frame(width: w * 0.22, height: h * 0.5)
                        .position(
                            x: w / 2 + CGFloat(wave3) * w * 0.18,
                            y: h - bandHeight * (0.3 + emberRise * 0.4)
                        )
                        .blur(radius: 14)
                        .blendMode(.plusLighter)

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [hueShift(accent, hueEmber2).opacity(lipEnergy * 0.28 * emberScale), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.12
                            )
                        )
                        .frame(width: w * 0.18, height: h * 0.42)
                        .position(
                            x: w / 2 - CGFloat(wave6) * w * 0.22,
                            y: h - bandHeight * (0.25 + (1 - emberRise) * 0.4)
                        )
                        .blur(radius: 15)
                        .blendMode(.plusLighter)

                    // Soft shimmer sweep — a faint light band drifting sideways
                    // across the pool, adding subtle motion like moving light.
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [hotTint.opacity(lipEnergy * 0.35), .clear],
                                center: .center, startRadius: 0, endRadius: w * 0.3
                            )
                        )
                        .frame(width: w * 0.55, height: bandHeight * 0.9)
                        .position(
                            x: w / 2 + CGFloat(wave1) * w * 0.35,
                            y: bodyY + CGFloat(wave4) * h * 0.04
                        )
                        .blur(radius: 18)
                        .blendMode(.plusLighter)

                    // Caustic light ripples — thin bright arcs that drift and
                    // cross near the lip, like light dancing on water. This is
                    // the layer that makes it read as "stunning" rather than flat.
                    ForEach(0..<3, id: \.self) { i in
                        let phase = Double(i) * 2.1
                        let rx = sin(t * speed * (0.5 + Double(i) * 0.17) + phase)
                        let ry = cos(t * speed * (0.4 + Double(i) * 0.13) + phase)
                        Capsule()
                            .fill(lipColor.opacity(lipEnergy * (0.16 - Double(i) * 0.03)))
                            .frame(
                                width: w * (0.5 - CGFloat(i) * 0.08),
                                height: h * 0.04
                            )
                            .rotationEffect(.degrees(Double(rx) * 12))
                            .position(
                                x: w / 2 + CGFloat(rx) * w * 0.16,
                                y: h - bandHeight * (0.22 + CGFloat(i) * 0.12)
                                    + CGFloat(ry) * h * 0.03
                            )
                            .blur(radius: 5)
                            .blendMode(.plusLighter)
                    }

                    // Faint top glass sheen
                    LinearGradient(
                        colors: [Color.white.opacity(isActive ? 0.06 : 0.03), .clear],
                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.35)
                    )
                    .blendMode(.plusLighter)

                    // Inner-edge vignette — darkens the rim so the glow feels
                    // contained inside the glass, adding depth.
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.38)],
                        center: .init(x: 0.5, y: 0.85),
                        startRadius: min(w, h) * 0.22,
                        endRadius: max(w, h) * 0.70
                    )
                }
                .animation(.easeInOut(duration: 0.5), value: state)
            }
        }
    }
}


#Preview {
    MockInterviewView()
        .modelContainer(for: ResumeItem.self, inMemory: true)
        .environmentObject(SubscriptionManager())
}
