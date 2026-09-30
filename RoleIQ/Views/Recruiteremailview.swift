//
//  Recruiteremailview.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 04/08/26.
//


import SwiftUI
import SwiftData
import MessageUI
import Combine
import Lottie
import UniformTypeIdentifiers

// MARK: - Model

struct RecruiterEmailDraft {
    var subject: String
    var body: String
}

// MARK: - Main View

struct RecruiterEmailView: View {
    @StateObject private var viewModel = RecruiterEmailViewModel()
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    var resumePDFData: Data? = nil
    var onOpenProfile: (() -> Void)? = nil
    @State private var showMailComposer = false
    @State private var showMailUnavailableAlert = false
    @State private var didAutofillName = false
    @State private var attachResume = true // user can toggle attaching

    // A resume picked right here in the email view. Overrides the one passed
    // in from Prep when present. Nil → fall back to resumePDFData.
    @State private var pickedPDFData: Data?
    @State private var pickedPDFName: String?
    @State private var showResumePicker = false
    @State private var pickerError: String?

    // Past sent emails, newest first.
    @Query(sort: \SentEmailEntity.dateSent, order: .reverse)
    private var sentEmails: [SentEmailEntity]

    // Re-opening a past send in a read-only sheet.
    @State private var openedEmail: SentEmailEntity?

    /// The PDF that will actually be attached: locally picked one wins, else
    /// the resume handed in from the Prep screen.
    private var effectiveResumeData: Data? {
        pickedPDFData ?? resumePDFData
    }

    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    inputForm
                    generateButton

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }

                    if viewModel.hasDraft {
                        draftPreview
                    }

                    // Past sends appear below the form when not mid-draft.
                    if !viewModel.hasDraft && !sentEmails.isEmpty {
                        sentHistorySection
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            confettiLayer
            toastLayer
            copyToastLayer
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Draft Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if !didAutofillName, viewModel.userName.isEmpty {
                viewModel.userName = authViewModel.userName ?? ""
                didAutofillName = true
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                recipient: viewModel.recruiterEmail,
                subject: viewModel.draftSubject,
                body: viewModel.draftBody,
                attachmentData: (attachResume ? effectiveResumeData : nil),
                onFinish: { result in
                    // Only record it as sent when the user actually sent it.
                    if result == .sent { saveSentEmail() }
                }
            )
        }
        .sheet(item: $openedEmail) { email in
            SentEmailDetailView(email: email)
        }
        .alert("Mail Not Set Up", isPresented: $showMailUnavailableAlert) {
            Button("Copy Instead") { copyToClipboard() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("No email account is configured on this device. You can copy the draft instead.")
        }
        .fileImporter(
            isPresented: $showResumePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePickedResume(result)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    // MARK: Background — black at top fading to violet at the bottom

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

    /// Runs the draft generation, or bounces free users who've hit the weekly cap
    /// straight to the paywall. Used by both Generate and Regenerate.
    private func attemptGenerate() {
        if !subscriptionManager.isProUser, RecruiterEmailLimit.hasReachedLimit {
            Haptics.error()
            onOpenProfile?()
            return
        }
        Haptics.medium()
        Task { await viewModel.generateDraft() }   // no increment here anymore
    }
    
    /// Regenerate an EXISTING draft — free, never counts or gates.
    private func attemptRegenerate() {
        Haptics.medium()
        Task { await viewModel.generateDraft() }
    }
    
    // MARK: Header — compact inline animation chip + title

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            // Small animation accent while there's no draft; once a draft
            // exists it gives way to the "new draft" button on the right so
            // the header stays uncluttered.
            if !viewModel.hasDraft {
                animationChip
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recruiter Outreach")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("AI drafts it. You review and send.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            if viewModel.hasDraft {
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut) { viewModel.startNewDraft() }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
    }

    /// Recolored envelope loop in a compact Liquid Glass chip (56pt).
    /// Uses "RecruiterEmailLoader.json" in the bundle.
    private var animationChip: some View {
        LottieView(name: "RecruiterEmailLoader")
            .frame(width: 52, height: 52)
            .padding(2)
            .modifier(EmailGlassCard(cornerRadius: 16, tint: violet))
    }

    // MARK: Subviews

    private var inputForm: some View {
        VStack(spacing: 16) {
            styledField("Your name", text: $viewModel.userName)
            styledField("Recruiter email", text: $viewModel.recruiterEmail, keyboard: .emailAddress)
            styledField("Company name", text: $viewModel.companyName)
            styledField("Role title", text: $viewModel.roleTitle)
            styledField("Job description (optional)", text: $viewModel.jobDescription, multiline: true)
            styledField("Brief summary of yourself (optional)", text: $viewModel.resumeSummary, multiline: true)
            toneSelector
        }
    }

    private var toneSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Picker("Tone", selection: $viewModel.tone) {
                ForEach(EmailTone.allCases) { tone in
                    Text(tone.rawValue).tag(tone)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.tone) { _, _ in
                Haptics.tap()
            }
        }
    }

    private var generateButton: some View {
        Button {
            attemptGenerate()
        } label: {
            HStack {
                if viewModel.isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel.isGenerating ? "Drafting…" : "Draft Email with AI")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(viewModel.isGenerating || viewModel.recruiterEmail.isEmpty || viewModel.roleTitle.isEmpty)
        .opacity((viewModel.recruiterEmail.isEmpty || viewModel.roleTitle.isEmpty) ? 0.5 : 1.0)
    }

    private func styledField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if multiline {
                Text(placeholder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Group {
                if multiline {
                    TextEditor(text: text)
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                } else {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(AppTheme.textMuted))
                        .keyboardType(keyboard)
                        .autocapitalization(keyboard == .emailAddress ? .none : .words)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(AppTheme.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: Draft preview (editable)

    private var draftPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Draft")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(viewModel.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Subject")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                TextField("", text: $viewModel.draftSubject)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Divider().overlay(AppTheme.textMuted)

                Text("Body")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                TextEditor(text: $viewModel.draftBody)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
            )

            regenerateButton

            resumeAttachSection

            HStack(spacing: 12) {
                Button {
                    Haptics.medium()
                    if MFMailComposeViewController.canSendMail() {
                        showMailComposer = true
                    } else {
                        showMailUnavailableAlert = true
                    }
                } label: {
                    Label("Review & Send", systemImage: "paperplane.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Haptics.tap()
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var regenerateButton: some View {
        Button {
            attemptRegenerate()
        } label: {
            HStack {
                if viewModel.isGenerating {
                    ProgressView().tint(AppTheme.textPrimary)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(viewModel.isGenerating ? "Regenerating…" : "Regenerate")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.08))
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(viewModel.isGenerating)
    }

    // MARK: Confetti + Toast

    private var confettiLayer: some View {
        ConfettiView(isActive: viewModel.showConfetti)
            .allowsHitTesting(false)
    }

    private var toastLayer: some View {
        VStack {
            if viewModel.showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Draft ready!")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(AppTheme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 12)
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showToast)
        .allowsHitTesting(false)
    }

    private var copyToastLayer: some View {
        VStack {
            if viewModel.showCopyToast {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                    Text("Copied!")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.accent.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 12)
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showCopyToast)
        .allowsHitTesting(false)
    }
    private func copyToClipboard() {
        UIPasteboard.general.string = "Subject: \(viewModel.draftSubject)\n\n\(viewModel.draftBody)"
        viewModel.flashCopyToast()
    }

    // MARK: - Resume attachment

    /// A filename for what's currently attached (picked one, or a generic
    /// label for the resume passed in from Prep).
    private var attachedResumeLabel: String? {
        if let name = pickedPDFName { return name }
        if resumePDFData != nil { return "Resume from Prep" }
        return nil
    }

    private var resumeAttachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label = attachedResumeLabel {
                // Something is attached: show it, a toggle, and a replace action.
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(attachResume ? "Will be attached" : "Not attached")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        showResumePicker = true
                    } label: {
                        Text("Replace")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Toggle(isOn: $attachResume) {
                    Label("Attach resume (PDF)", systemImage: "paperclip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .tint(AppTheme.accent)
                .onChange(of: attachResume) { _, _ in Haptics.tap() }
            } else {
                // Nothing attached yet: offer the picker.
                Button {
                    Haptics.tap()
                    showResumePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                        Text("Attach a resume (PDF)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }

            if let pickerError {
                Text(pickerError)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1))
        )
    }

    /// Reads a picked PDF into memory (security-scoped) so it can be attached.
    private func handlePickedResume(_ result: Result<[URL], Error>) {
        pickerError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pickedPDFData = data
                pickedPDFName = url.lastPathComponent
                attachResume = true
                Haptics.success()
            } catch {
                pickerError = "Couldn't read that PDF. Try another file."
                Haptics.error()
            }
        case .failure:
            pickerError = "Couldn't open the file picker."
            Haptics.error()
        }
    }

    // MARK: - Sent email history

    /// Persists the email that was just sent. Called only when the mail
    /// composer reports .sent.
    private func saveSentEmail() {
        let entity = SentEmailEntity(
            companyName: viewModel.companyName.trimmingCharacters(in: .whitespaces),
            roleTitle: viewModel.roleTitle.trimmingCharacters(in: .whitespaces),
            recipient: viewModel.recruiterEmail.trimmingCharacters(in: .whitespaces),
            subject: viewModel.draftSubject,
            body: viewModel.draftBody
        )
        modelContext.insert(entity)
        try? modelContext.save()
        if !subscriptionManager.isProUser { RecruiterEmailLimit.increment() }  // count on actual send
        Haptics.success()
    }

    private var sentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SENT EMAILS")
                .font(.system(size: 11, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 8)

            ForEach(sentEmails) { email in
                Button {
                    Haptics.tap()
                    openedEmail = email
                } label: {
                    SentEmailRow(email: email)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Glass card modifier

/// Liquid Glass container for the email header band: real .glassEffect on
/// iOS 26+, .ultraThinMaterial fallback below.
private struct EmailGlassCard: ViewModifier {
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

// MARK: - Native Confetti (no Lottie)

struct ConfettiView: View {
    let isActive: Bool
    @State private var pieces: [ConfettiPiece] = []

    private let colors: [Color] = [
        AppTheme.accent, AppTheme.accentDeep, AppTheme.accentSoft, .white
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.4)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                        .opacity(piece.opacity)
                }
            }
            .onChange(of: isActive) { _, active in
                if active { burst(in: geo.size) }
            }
        }
    }

    private func burst(in size: CGSize) {
        pieces = (0..<120).map { _ in
            ConfettiPiece(
                x: size.width / 2 + CGFloat.random(in: -40...40),
                y: size.height * 0.3,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...11),
                rotation: .random(in: 0...360),
                opacity: 1
            )
        }

        for index in pieces.indices {
            let destX = CGFloat.random(in: 0...size.width)
            let destY = size.height + CGFloat.random(in: 20...140)
            let dur = Double.random(in: 1.2...2.2)

            withAnimation(.easeOut(duration: dur)) {
                pieces[index].x = destX
                pieces[index].y = destY
                pieces[index].rotation += Double.random(in: 180...720)
            }
            withAnimation(.easeIn(duration: dur).delay(dur * 0.4)) {
                pieces[index].opacity = 0
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var rotation: Double
    var opacity: Double
}

// MARK: - Mail Composer Wrapper

struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    var attachmentData: Data? = nil
    var onFinish: ((MFMailComposeResult) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        if let data = attachmentData {
            composer.addAttachmentData(data, mimeType: "application/pdf", fileName: "resume.pdf")
        }
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss, onFinish: onFinish) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        let onFinish: ((MFMailComposeResult) -> Void)?
        init(dismiss: DismissAction, onFinish: ((MFMailComposeResult) -> Void)?) {
            self.dismiss = dismiss
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish?(result)
            dismiss()
        }
    }
}
// MARK: - Sent email row

private struct SentEmailRow: View {
    let email: SentEmailEntity

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: email.dateSent)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
                    .frame(width: 42, height: 42)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accentSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Sent to \(email.displayCompany)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !email.roleTitle.isEmpty {
                    Text(email.roleTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSoft)
                        .lineLimit(1)
                }
                Text(dateText)
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

// MARK: - Sent email detail (read-only)

private struct SentEmailDetailView: View {
    let email: SentEmailEntity
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return f.string(from: email.dateSent)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.55),
                        .init(color: Color(red: 0.16, green: 0.06, blue: 0.26), location: 1.0)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("To: \(email.recipient)")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Sent \(dateText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Divider().overlay(Color.white.opacity(0.1))

                        Text("Subject")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(email.subject)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Body")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 8)
                        Text(email.body)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                    .padding()
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Sent Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecruiterEmailView()
        .environment(AuthViewModel())
        .environmentObject(SubscriptionManager())
        .modelContainer(for: [SentEmailEntity.self], inMemory: true)
        .preferredColorScheme(.dark)
}
