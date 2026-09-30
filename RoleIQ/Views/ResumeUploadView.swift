//
//  ResumeUploadView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//


//
//  Input screen: upload + role + YoE + optional JD. On success it saves an
//  ATSHistoryItem and pushes ATSResultView. Past checks appear as cards below
//  the upload — tap one to re-open its saved result.
//
//  Header uses a Lottie resume-scan loop inside a Liquid Glass card
//  (.glassEffect on iOS 26, .ultraThinMaterial fallback below). A time-aware
//  greeting personalises with the signed-in first name when available. When no
//  resume is uploaded yet, a "How it works" strip fills the space and orients
//  first-time users; the recruiter-email card stays visible in both states.
//


import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var authViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var onOpenProfile: (() -> Void)? = nil
    
    @State private var viewModel: ResumeUploadViewModel?
    @State private var isShowingPicker = false
    @State private var path = NavigationPath()
    @State private var showLimitBanner = false
    // Drives the staggered fade-in of the "How it works" steps.
    @State private var stepsAppeared = false

    // Past ATS checks, newest first.
    @Query(sort: \ATSHistoryItem.dateAdded, order: .reverse)
    private var history: [ATSHistoryItem]

    // MARK: ATS state
    @State private var jobRole = ""
    @State private var yoeText = ""
    @State private var jobDescription = ""
    @State private var showJDField = false
    @State private var isScoring = false
    @State private var atsError: String?
    @State private var showEmailDraft = false

    // Drives navigation to the results screen.
    @State private var resultForNav: ATSScoreResult?

    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

    private var hasResume: Bool { !(viewModel?.extractedText.isEmpty ?? true) }

    private var canAnalyze: Bool {
        hasResume
            && !jobRole.trimmingCharacters(in: .whitespaces).isEmpty
            && !isScoring
    }

    // MARK: - Greeting

    /// Signed-in first name, if we have one persisted. Full name is stored;
    /// we show only the first token so the greeting stays short.
    private var firstName: String? {
        guard let full = authViewModel.userName?
            .trimmingCharacters(in: .whitespaces), !full.isEmpty else { return nil }
        return full.split(separator: " ").first.map(String.init)
    }

    /// "Good morning" / "Good afternoon" / "Good evening" by local hour,
    /// with the first name appended only when we actually have one (no
    /// dangling comma, no placeholder).
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12:  part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default:      part = "Good evening"
        }
        if let name = firstName { return "\(part), \(name)" }
        return part
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                backgroundLayer

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        uploadCard
                        emailDraftCard

                        if hasResume {
                            fieldsSection
                            jdDisclosure
                            analyzeButton
                        }

                        if let vm = viewModel, vm.isProcessing {
                            ProgressView("Extracting text…")
                                .tint(violet)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.top, 8)
                        }

                        if let error = viewModel?.errorMessage { inlineError(error) }
                        if let atsError { inlineError(atsError) }

                        // Below the fold: how-it-works (pre-upload) then past checks.
                        if !hasResume { howItWorks }

                        if !history.isEmpty {
                            historySection
                        } else if !hasResume {
                            emptyHint
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
            .navigationTitle("Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: ChatSessionEntity.self) { entity in
                ChatView(entity: entity, isSidebarOpen: .constant(false))
            }
            .navigationDestination(item: $resultForNav) { result in
                ATSResultView(result: result) {
                    resultForNav = nil
                }
            }
            .navigationDestination(isPresented: $showEmailDraft) {
                RecruiterEmailView(resumePDFData: viewModel?.resumePDFData, onOpenProfile: onOpenProfile)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ResumeUploadViewModel(modelContext: modelContext)
                }
                // One orchestrated reveal for the steps.
                if !stepsAppeared {
                    withAnimation(.easeOut(duration: 0.5)) { stepsAppeared = true }
                }
            }
            .fileImporter(
                isPresented: $isShowingPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        atsError = nil
                        Haptics.tap()
                        viewModel?.handlePickedPDF(url: url)
                    }
                case .failure(let error):
                    viewModel?.errorMessage = error.localizedDescription
                }
            }
        }
        .preferredColorScheme(.dark)
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

    // MARK: - Header (Lottie glass card + greeting)

    private var header: some View {
        VStack(spacing: 14) {
            lottieGlassBand

            VStack(spacing: 6) {
                Text("RESUME CHECK")
                    .font(.system(size: 11, weight: .bold)).tracking(3)
                    .foregroundStyle(.white.opacity(0.4))

                Text(greetingText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.655, green: 0.545, blue: 0.980)) // accentSoft

                Text("How well does your resume score?")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // The pitch shows only pre-upload; returning users skip it.
                if !hasResume {
                    Text("Get an instant ATS score and see exactly what to fix before you apply.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.top, 8)
    }

    /// The recolored resume-scan animation inside a Liquid Glass card.
    /// Real .glassEffect on iOS 26; .ultraThinMaterial fallback below.
    private var lottieGlassBand: some View {
        LottieView(name: "ResumeScanLoader")
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .modifier(GlassCard(cornerRadius: 22, tint: violet))
    }

    // MARK: - Upload

    private var uploadCard: some View {
        Button {
            Haptics.tap()
            isShowingPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hasResume ? "checkmark.circle.fill" : "doc.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(hasResume ? Color(red: 0.3, green: 0.85, blue: 0.55) : violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasResume ? "Resume uploaded" : "Upload your resume")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(hasResume ? "Tap to replace (PDF)" : "PDF · scored in seconds")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(violet.opacity(hasResume ? 0.4 : 0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - How it works (pre-upload only)

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOW IT WORKS")
                .font(.system(size: 11, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)

            // The three steps share one glass panel; a single continuous line
            // runs behind the icon column so the sequence reads as one unit.
            VStack(alignment: .leading, spacing: 0) {
                howStep(
                    index: 0,
                    icon: "doc.badge.plus",
                    title: "Upload your resume",
                    detail: "PDF only. It stays on your device — we read the text, never store the file."
                )
                howStep(
                    index: 1,
                    icon: "target",
                    title: "Add your target role",
                    detail: "Tell us the job you're aiming for — paste the posting for an even sharper match."
                )
                howStep(
                    index: 2,
                    icon: "checkmark.seal",
                    title: "Get your score in seconds",
                    detail: "A 0–100 ATS score, matched and missing keywords, and specific fixes."
                )
            }
            .background(alignment: .topLeading) {
                // Line spans from the first icon's center to the last icon's
                // center. Inset from top/bottom by roughly half a row so it
                // starts/ends at icon centers, and offset right to the icon's
                // horizontal center (16 leading pad + 17 half-icon = ~17 here,
                // measured from the VStack's leading edge → icon center at 17).
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [violet.opacity(0.45), violet.opacity(0.15)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .padding(.vertical, 31)   // ~half a row: aligns ends to icon centers
                    .offset(x: 16)            // icon center: 17 half-width - 1 half-line
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .modifier(GlassCard(cornerRadius: 18, tint: violet))
        }
        .padding(.top, 8)
    }

    private func howStep(
        index: Int, icon: String, title: String, detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon sits on an opaque-enough chip so the connector line behind
            // the column doesn't show through it.
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppTheme.background)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(violet.opacity(0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(violet.opacity(0.35), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.655, green: 0.545, blue: 0.980))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .opacity(stepsAppeared ? 1 : 0)
        .offset(y: stepsAppeared ? 0 : 8)
        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.08), value: stepsAppeared)
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(spacing: 14) {
            inputField(title: "Target role", placeholder: "e.g. iOS Engineer", text: $jobRole)
            inputField(title: "Years of experience", placeholder: "e.g. 3",
                       text: $yoeText, keyboard: .numberPad)
        }
    }

    private var jdDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.25)) { showJDField.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showJDField ? "minus.circle" : "plus.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(showJDField ? "Remove job description" : "Add job description (more accurate)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(violet)
            }

            if showJDField {
                ZStack(alignment: .topLeading) {
                    if jobDescription.isEmpty {
                        Text("Paste the job post here for a match tuned to the exact role…")
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 20).padding(.vertical, 18)
                    }
                    TextEditor(text: $jobDescription)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
            }
        }
    }

    private func inputField(
        title: String, placeholder: String,
        text: Binding<String>, keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            TextField("", text: text,
                      prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                .keyboardType(keyboard)
                .foregroundStyle(.white).font(.system(size: 18))
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
        }
    }

    private var analyzeButton: some View {
        Button(action: runAnalysis) {
            HStack(spacing: 8) {
                if isScoring { ProgressView().tint(.white) }
                else { Image(systemName: "wand.and.stars") }
                Text(isScoring ? "Analyzing…" : "Analyze resume")
            }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(violet.opacity(canAnalyze ? 1 : 0.3))
                    .shadow(color: violet.opacity(canAnalyze ? 0.4 : 0), radius: 12, y: 4)
            )
        }
        .disabled(!canAnalyze)
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAST CHECKS")
                .font(.system(size: 11, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            ForEach(history) { item in
                Button {
                    Haptics.tap()
                    if let decoded = item.decodedResult {
                        resultForNav = decoded
                    }
                } label: {
                    HistoryRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Shown only when there's no resume AND no history — a gentle nudge.
    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.25))
            Text("Your past checks will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Recruiter email card (visible in both states)

    private var emailDraftCard: some View {
        Button {
            Haptics.tap()
            showEmailDraft = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draft a recruiter email")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("AI writes it — you review and send")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(violet.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func runAnalysis() {
        guard let vm = viewModel else { return }

        if !subscriptionManager.isProUser, ResumeScoringLimit.hasReachedLimit {
            Haptics.error()
            onOpenProfile?()
            return
        }

        let role = jobRole.trimmingCharacters(in: .whitespaces)
        let yoe = Int(yoeText.trimmingCharacters(in: .whitespaces)) ?? 0

        atsError = nil; isScoring = true
        Haptics.medium()
        // NOTE: increment moved to the success branch below — a failed scan must NOT count.

        Task {
            do {
                let result = try await BackendService.shared.scoreResume(
                    resumeText: vm.extractedText,
                    jobRole: role,
                    yearsOfExperience: yoe,
                    jobDescription: showJDField ? jobDescription : nil,
                    useGemini: true
                )
                await MainActor.run {
                    isScoring = false
                    Haptics.success()
                    if !subscriptionManager.isProUser { ResumeScoringLimit.increment() }  // only on success
                    saveToHistory(result, role: role)
                    resultForNav = result
                }
            } catch {
                await MainActor.run {
                    atsError = friendlyMessage(for: error)
                    isScoring = false
                    Haptics.error()
                    // NOT counted — the scan failed.
                }
            }
        }
    }

    private func saveToHistory(_ result: ATSScoreResult, role: String) {
        guard let item = ATSHistoryItem.from(
            result: result, jobRole: role, modelUsed: result.modelUsed
        ) else { return }
        modelContext.insert(item)
        try? modelContext.save()
    }

    private func friendlyMessage(for error: Error) -> String {
        if let be = error as? BackendService.BackendError {
            switch be {
            case .rateLimited:        return "Too many requests. Give it a moment and try again."
            case .badResponse:        return "Couldn't reach the server. Check your connection."
            case .parsingFailed:      return "Got an unexpected response from the server."
            case .serverError(let m): return m
            }
        }
        return error.localizedDescription
    }

    private func startNewChat() {
        let entity = ChatSessionEntity()
        modelContext.insert(entity)
        try? modelContext.save()
        path.append(entity)
    }
}

// MARK: - Glass card modifier

/// Liquid Glass container: real .glassEffect on iOS 26+, graceful
/// .ultraThinMaterial fallback below. The tinted stroke keeps the violet
/// identity on both paths.
private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.10)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.15), radius: 20, y: 0)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.07))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.15), radius: 20, y: 0)
        }
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let item: ATSHistoryItem
    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965)

    private var scoreColor: Color {
        switch item.atsScore {
        case ..<40:   return Color(red: 1.0, green: 0.5, blue: 0.42)
        case 40..<70: return Color(red: 1.0, green: 0.75, blue: 0.35)
        default:      return Color(red: 0.45, green: 0.85, blue: 0.6)
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: item.dateAdded)
    }

    private var remarkText: String {
        switch item.atsScore {
        case 80...:   return "Strong match — interview ready"
        case 60..<80: return "Solid — a little polish needed"
        case 40..<60: return "Needs work"
        default:      return "Major gaps to fix"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Score badge
            ZStack {
                Circle().stroke(scoreColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(min(100, max(0, item.atsScore))) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                Text("\(item.atsScore)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.jobRole)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(remarkText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(scoreColor)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(item.matchPercent)% match")
                    Text("·")
                    Text(dateText)
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

#Preview {
    ResumeUploadView()
        .environment(AuthViewModel())
        .environmentObject(SubscriptionManager())
        .modelContainer(for: [ResumeItem.self, ChatSessionEntity.self, ATSHistoryItem.self], inMemory: true)
        .preferredColorScheme(.dark)
}
