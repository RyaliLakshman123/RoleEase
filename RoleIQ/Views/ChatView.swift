//
//  ChatView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 02/08/26.
//


import SwiftUI
import SwiftData
import PhotosUI

enum ChatTheme {
    static let background = Color(red: 0.05, green: 0.03, blue: 0.09)
    // Same black -> violet gradient used in MockInterviewView's backgroundLayer.
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.55),
            .init(color: Color(red: 0.16, green: 0.06, blue: 0.26), location: 1.0)
        ]),
        startPoint: .top, endPoint: .bottom
    )
    static let surface = Color(red: 0.13, green: 0.09, blue: 0.19)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let violet = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    static let violetDeep = Color(red: 0.33, green: 0.10, blue: 0.72)
    static let primaryGradient = LinearGradient(
        colors: [violet, violetDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradient = RadialGradient(
        colors: [violet, violetDeep, .clear],
        center: .center,
        startRadius: 2,
        endRadius: 60
    )
}

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @State private var glassRefresh = 0
    
    let entity: ChatSessionEntity
    var userName: String = "there"          // fallback if auth has no name yet
    var profileImage: UIImage? = nil
    var onNewChat: (() -> Void)? = nil
    var onOpenProfile: (() -> Void)? = nil

    // Sidebar open/close is owned by the container; ChatView just reads & flips it.
    @Binding var isSidebarOpen: Bool

    
    private let allModes: [CareerMode] = [.general, .resumeReview, .mockInterview, .coverLetter, .jdMatch, .roadmap]
    @State private var showModePicker = false
    
    var body: some View {
        ZStack {
            ChatTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.didConfigure {
                    Color.clear
                } else if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                inputBar
            }

            // Floating glass icons — overlaid on top, content scrolls under them.
            VStack {
                topBar
                Spacer()
            }
        }
        .task {
            viewModel.configure(context: modelContext, entity: entity)
        }
        .onAppear {
            viewModel.isProUser = subscriptionManager.isProUser
        }
        .onChange(of: subscriptionManager.isProUser) { _, newValue in
            viewModel.isProUser = newValue
        }
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showModePicker) {
            modePickerSheet
        }
    }

    // MARK: - Top bar (glass)
    // Sidebar (history) on the left, model switcher centered, and new-chat +
    // Pro-upgrade crown on the right. The crown is the paywall entry; Settings
    // lives in the sidebar's gear.

    private var topBar: some View {
        HStack(spacing: 10) {
            glassCircleButton(systemImage: "line.3.horizontal.decrease") {
                Haptics.tap()

                // Dismiss the keyboard before opening the sidebar
                inputFocused = false

                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isSidebarOpen = true
                }
            }

            Spacer()

            //modelPill

            Spacer()

            glassCircleButton(systemImage: "square.and.pencil") {
                Haptics.tap()
                onNewChat?()
            }

            crownButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // Pro-upgrade entry. Gold to signal premium, with a soft shine that sweeps
    // across it now and then — a small, native "this is special" cue.
    private var crownButton: some View {
        Button {
            Haptics.medium()
            // TODO(paywall): present the RevenueCat paywall here.
            onOpenProfile?()
        } label: {
            ShimmerCrown()
                .frame(width: 36, height: 36)
        }
        .glassBackground(in: Circle())
    }

    private var modelPill: some View {
        Menu {
            ForEach(RoleIQModel.allCases, id: \.self) { option in
                Button {
                    Haptics.tap()
                    viewModel.model = option
                } label: {
                    Label(option.badge, systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("RoleEase").font(.subheadline.weight(.semibold))
                Text(viewModel.model.badge).font(.subheadline.weight(.regular))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(ChatTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .glassBackground(in: Capsule())
    }

    private func glassCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(ChatTheme.textPrimary)
                .frame(width: 36, height: 36)
        }
        .glassBackground(in: Circle())
    }

    // MARK: - Empty state (home)
    // The primary home surface. Chat is the star here, so the layout leads with
    // a warm, time-aware greeting and a soft hero glow, then keeps the modes
    // quiet: a single scrollable row of starter prompts sits just above the
    // input bar. Tapping one pre-fills the input (and selects the matching mode)
    // so the user reviews before sending — chat stays primary, modes introduced
    // gently rather than shoved forward.

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Clean, minimal greeting — no hero graphic.
            VStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ChatTheme.violet)
                    .tracking(0.5)

                Text("What can I help with?")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(ChatTheme.textPrimary)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Quiet starter prompts — a soft launchpad, not a loud grid.
            starterPrompts
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // Time-of-day + name. Falls back gracefully when the name is the default.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12:  part = "Good morning"
        case 12..<17: part = "Good afternoon"
        case 17..<22: part = "Good evening"
        default:      part = "Good evening"
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        return (name.isEmpty || name == "there") ? part : "\(part), \(name)"
    }

    // MARK: Starter prompts
    // Each prompt carries the mode it belongs to. `needsInput` decides tap
    // behaviour: prompts that require something from the user (a resume, a job
    // description, specifics) fill the input and focus it so they can add detail;
    // self-contained prompts send immediately for a one-tap start.

    private struct StarterPrompt: Identifiable {
        let id = UUID()
        let mode: CareerMode
        let label: String
        let text: String
        let needsInput: Bool
    }

    private var starters: [StarterPrompt] {
        [
            .init(mode: .resumeReview,  label: "Review my resume",   text: "Can you review my resume and score it?",       needsInput: true),
            .init(mode: .mockInterview, label: "Practice interview", text: "I'd like to practice a mock interview.",        needsInput: false),
            .init(mode: .coverLetter,   label: "Cover letter",       text: "Help me write a cover letter.",                 needsInput: true),
            .init(mode: .jdMatch,       label: "Match a job",        text: "Match my profile to a job description.",        needsInput: true),
            .init(mode: .roadmap,       label: "Career roadmap",     text: "Build me a skill-building roadmap.",            needsInput: false)
        ]
    }

    private var starterPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(starters) { prompt in
                    Button {
                        Haptics.tap()
                        viewModel.selectedMode = prompt.mode
                        viewModel.draftInput = prompt.text
                        if prompt.needsInput {
                            // Needs the user to add a resume / JD / detail first.
                            inputFocused = true
                        } else {
                            // Self-contained — fire it off for a one-tap start.
                            inputFocused = false
                            viewModel.sendMessage()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: prompt.mode.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ChatTheme.violet)
                            Text(prompt.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(ChatTheme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassBackground(in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Mode badge (tap to open picker)
    // Commented out at the call site above for now — kept here so it can be
    // dropped back in (or moved to a new location) later without rewriting it.

    private var modeBadge: some View {
        HStack {
            Spacer()
            Button {
                showModePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedMode.icon)
                        .font(.caption.weight(.semibold))
                    Text(viewModel.selectedMode.title)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(ChatTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .glassBackground(in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var modePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(allModes, id: \.self) { mode in
                        modePickerRow(mode)
                    }
                }
                .padding(16)
            }
            .background(ChatTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Chat mode")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationBackground(.thickMaterial)
    }

    private func modePickerRow(_ mode: CareerMode) -> some View {
        let isSelected = viewModel.selectedMode == mode
        return Button {
            Haptics.success()
            viewModel.selectedMode = mode
            entity.mode = mode
            try? modelContext.save()
            showModePicker = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : ChatTheme.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChatTheme.textPrimary)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(ChatTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ChatTheme.violet)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassBackground(in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)   // no animation — keeps up with streaming
        }
    }
    
    //MARK: Message list
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            onCopy: { viewModel.copyMessage(message) },
                            onRegenerate: { viewModel.regenerate(messageID: message.id) },
                            onFeedback: { liked in viewModel.setFeedback(messageID: message.id, liked: liked) },
                            onEdit: { viewModel.beginEditing(messageID: message.id) }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)   // clears the floating top bar
                .padding(.bottom, 12)
            }
//            .mask(
//                LinearGradient(
//                    stops: [
//                        .init(color: .clear, location: 0.0),
//                        .init(color: .black, location: 0.08)
//                    ],
//                    startPoint: .top, endPoint: .bottom
//                )
//            )
            // Only scroll down when a NEW message is added (count changes).
            // Nothing fires on keyboard open or on each streaming tick, so the
            // view no longer jumps around.
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: viewModel.streamTick) { _, _ in
                scrollToBottom(proxy, animated: false)
            }
        }
    }
    
    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }

    // MARK: - Input bar (glass, floating capsule)

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false

    // Attachment handling. Everything picked is turned into TEXT on-device and
    // held as a hidden attachment on the view model (shown as a pill), then
    // merged into the message at send time.
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingAttachment = false

    private var inputBar: some View {
        VStack(spacing: 8) {
            if isProcessingAttachment || viewModel.hasAttachment {
                attachmentStatusBar
            }
            
            if freeLimitReached {
                Button { Haptics.medium(); onOpenProfile?() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.30))
                        Text("You've used today's \(FreeMessageLimit.dailyLimit) free messages — upgrade for unlimited")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ChatTheme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassBackground(in: Capsule())
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 10) {
                attachMenu
                tierPill

                ZStack(alignment: .leading) {
                    if viewModel.draftInput.isEmpty {
                        Text("Ask RoleEase anything...")
                            .foregroundStyle(ChatTheme.textSecondary)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.draftInput)
                        .textEditorStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundStyle(ChatTheme.textPrimary)
                        .tint(ChatTheme.violet)
                        .frame(minHeight: 22, maxHeight: 96)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($inputFocused)
                }

                trailingActionButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().fill(ChatTheme.violet.opacity(0.08))
                    .allowsHitTesting(false)
            )
            .overlay(
                Capsule().stroke(ChatTheme.violet.opacity(0.25), lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // Photos → OCR text
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePickedPhoto(newItem) }
        }
        // Camera → OCR text
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await handleCapturedImage(image) }
            }
            .ignoresSafeArea()
        }
        // Files → PDF/text extraction (with OCR fallback for scanned PDFs)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            Task { await handlePickedFile(result) }
        }
        .onChange(of: showCamera) { _, isShown in
            if !isShown { glassRefresh += 1 }
        }
        .onChange(of: showFileImporter) { _, isShown in
            if !isShown { glassRefresh += 1 }
        }
        .onChange(of: showPhotoPicker) { _, isShown in
            if !isShown { glassRefresh += 1 }
        }
    }

    // A slim status row above the input: spinner while working, then a pill
    // showing the attached file's name with an ✕ to remove it. The pill is
    // driven by the view model, so it clears automatically after send.
    private var attachmentStatusBar: some View {
        HStack(spacing: 8) {
            if isProcessingAttachment {
                ProgressView()
                    .controlSize(.small)
                    .tint(ChatTheme.violet)
                Text("Reading attachment…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ChatTheme.textSecondary)
            } else if let label = viewModel.attachmentLabel {
                Image(systemName: "paperclip")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ChatTheme.violet)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ChatTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    Haptics.tap()
                    withAnimation { viewModel.clearAttachment() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ChatTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: Capsule())
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var attachMenu: some View {
        Menu {
            Button { Haptics.tap(); showPhotoPicker = true } label: {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            Button {
                Haptics.tap()
                // Guard: only open the camera when the device actually has one
                // (Simulator has none). Prevents a dead tap / crash and shows a
                // clear message instead.
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    viewModel.errorMessage = "Camera isn't available on this device."
                    Haptics.error()
                }
            } label: {
                Label("Camera", systemImage: "camera.fill")
            }
            Button { Haptics.tap(); showFileImporter = true } label: {
                Label("Files", systemImage: "doc.fill")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ChatTheme.textSecondary)
                .frame(width: 30, height: 30)
        }
    }

    // MARK: - Attachment handling
    // Each handler turns its input into text on-device, then appends a labelled
    // block to draftInput so the user sees what was added and can edit or add a
    // question before sending. Nothing changes in the send path or the backend.

    private func appendExtractedText(_ text: String, label: String) {
        // Hold the text as a hidden attachment (shown as a pill), not in the
        // input field. It's merged into the message at send time by the VM.
        viewModel.attach(text: text, label: label)
        withAnimation {
            isProcessingAttachment = false
        }
        Haptics.success()
        inputFocused = true
    }

    private func failAttachment(_ message: String) {
        withAnimation {
            isProcessingAttachment = false
            viewModel.clearAttachment()
        }
        Haptics.error()
        viewModel.errorMessage = message
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        withAnimation { isProcessingAttachment = true }
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                failAttachment("Couldn't load that photo."); return
            }
            let text = try await AttachmentProcessor.extractText(fromImage: image)
            appendExtractedText(text, label: "photo")
        } catch {
            failAttachment((error as? LocalizedError)?.errorDescription ?? "Couldn't read that photo.")
        }
    }

    private func handleCapturedImage(_ image: UIImage) async {
        withAnimation { isProcessingAttachment = true }
        do {
            let text = try await AttachmentProcessor.extractText(fromImage: image)
            appendExtractedText(text, label: "scan")
        } catch {
            failAttachment((error as? LocalizedError)?.errorDescription ?? "Couldn't read that scan.")
        }
    }

    private func handlePickedFile(_ result: Result<[URL], Error>) async {
        withAnimation { isProcessingAttachment = true }
        do {
            guard let url = try result.get().first else {
                failAttachment("No file selected."); return
            }
            let text = try await AttachmentProcessor.extractText(fromFile: url)
            appendExtractedText(text, label: url.lastPathComponent)
        } catch {
            failAttachment((error as? LocalizedError)?.errorDescription ?? "Couldn't read that file.")
        }
    }

    private var micButton: some View {
        Button {
            // hook up dictation / speech-to-text for draftInput
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ChatTheme.textSecondary)
                .frame(width: 30, height: 30)
        }
    }

    /// Light / Medium / Hard picker, shown in the input bar like the
    /// reference screenshot's model pill. Works the same in Free and Pro —
    /// it only ever sets viewModel.selectedTier, which is sent to the
    /// backend as "tier" alongside isPro/mode.
    private var tierPill: some View {
        Menu {
            ForEach(ModelTier.allCases, id: \.self) { tier in
                Button {
                    Haptics.tap()
                    viewModel.selectedTier = tier
                } label: {
                    Label(tier.label, systemImage: tier.icon)
                }
            }
        } label: {
            Image(systemName: viewModel.selectedTier.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ChatTheme.textSecondary)
                .frame(width: 36, height: 36)
            }
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().fill(ChatTheme.violet.opacity(0.08)).allowsHitTesting(false))
                .overlay(Circle().stroke(ChatTheme.violet.opacity(0.25), lineWidth: 1).allowsHitTesting(false))
    }

    private var freeLimitReached: Bool {
        !subscriptionManager.isProUser && FreeMessageLimit.hasReachedLimit
    }
    
    /// Sends the typed message when there's text; otherwise opens the
    /// voice-assistant orb (drop your amplitude-reactive orb view in here —
    /// same one from your other app, growing on voice input, idle otherwise).
    private var trailingActionButton: some View {
        Group {
            if viewModel.isStreaming {
                Button { Haptics.medium(); viewModel.stopStreaming() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(ChatTheme.primaryGradient, in: Circle())
                }
            } else if freeLimitReached {
                Button { Haptics.medium(); onOpenProfile?() } label: {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.78, blue: 0.30),
                                         Color(red: 0.82, green: 0.60, blue: 0.16)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                }
            } else {
                let hasText = !viewModel.draftInput.trimmingCharacters(in: .whitespaces).isEmpty
                let canSend = hasText || viewModel.hasAttachment
                Button {
                    Haptics.tap()
                    inputFocused = false
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(canSend ? AnyShapeStyle(ChatTheme.primaryGradient) : AnyShapeStyle(ChatTheme.textSecondary.opacity(0.3)), in: Circle())
                }
                .disabled(!canSend)
            }
        }
    }
}

/// Placeholder for your amplitude-reactive voice orb. Replace the body with
/// your existing implementation — keep the same call signature (an action
/// closure) so it drops in without touching ChatView.
private struct VoiceOrbButton: View {
    var action: () -> Void
    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(ChatTheme.primaryGradient)
                .frame(width: 32, height: 32)
                .scaleEffect(pulsing ? 1.08 : 1.0)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Camera picker
// Thin UIImagePickerController wrapper for capturing a document photo. The
// captured image is handed back and run through on-device OCR — no image ever
// leaves the device or reaches the backend.

private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Avatar generator
// Produces consistent initials + a deterministic violet-family gradient from the
// user's name, so every account gets a distinct-but-on-brand avatar without a photo.

enum AvatarGenerator {

    /// The preset palette shown in the color picker (matches the mockup).
    /// Stored/compared as hex so a choice survives relaunches.
    static let palette: [String] = [
        "8B5CF6", // violet (brand)
        "1D9E75", // teal
        "D85A30", // coral
        "378ADD", // blue
        "D4537E", // pink
        "F59E0B", // amber
        "10B981", // emerald
        "EF4444", // red
        "6366F1", // indigo
        "EC4899"  // hot pink
    ]

    /// Up-to-two-letter initials from a name. "?" when empty.
    static func initials(for name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.isEmpty { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
    }

    /// Deterministic hash of a string (unlike Swift's hashValue, which is
    /// randomized per launch — that made the old auto-color change on restart).
    private static func stableHash(_ s: String) -> Int {
        var hash = 5381
        for byte in s.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return abs(hash)
    }

    /// The auto/derived hex for a name — stable across launches. Picks from
    /// the same palette so derived and chosen colors look consistent.
    static func derivedHex(for name: String) -> String {
        guard !name.isEmpty else { return palette[0] }
        return palette[stableHash(name) % palette.count]
    }

    /// A solid Color from a hex string (falls back to violet on bad input).
    static func color(hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else {
            return AppTheme.accent
        }
        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }

    /// A two-tone gradient built from a base hex — the darker stop is the same
    /// hue dimmed, so every avatar keeps the app's depth look.
    static func gradient(hex: String) -> LinearGradient {
        let base = color(hex: hex)
        return LinearGradient(
            colors: [base, base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Back-compat shims
    // Old call sites use gradient(for:) / initials(for:). Keep them working by
    // routing through the deterministic derived color, so nothing else breaks
    // until we migrate each avatar to read the stored color.
    static func gradient(for name: String) -> LinearGradient {
        gradient(hex: derivedHex(for: name))
    }
}

// MARK: - Shimmer crown
// Gold crown for the Pro-upgrade entry. A diagonal highlight sweeps across the
// glyph on a slow cycle (via a moving mask), giving a subtle metallic "shine"
// without any dependency. Gold is an intentional exception to the violet
// palette — reserved for the paywall accent, where it reads as premium.

private struct ShimmerCrown: View {
    // Warm gold gradient for the crown fill.
    private let gold = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.90, blue: 0.55),   // light gold
            Color(red: 0.98, green: 0.78, blue: 0.30),   // core gold
            Color(red: 0.82, green: 0.60, blue: 0.16)    // deep gold
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            // Sweep runs 0→1 over ~1.0s, then rests until the cycle repeats
            // every ~2.6s — frequent enough to catch the eye, sparse enough
            // to stay tasteful.
            let period = 2.6
            let phase = t.truncatingRemainder(dividingBy: period) / 1.0
            let sweep = min(max(phase, 0), 1)
            let x = -0.6 + sweep * 1.8                     // travel across the glyph

            // Gentle gold breathing so the crown has a little life between
            // sweeps, not a dead glyph waiting to shine.
            let pulse = (sin(t * 1.6) + 1) / 2             // 0…1
            let glow = 0.30 + pulse * 0.35                 // shadow strength

            Image(systemName: "crown.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(gold)
                .scaleEffect(0.97 + pulse * 0.06)          // subtle breathe
                .overlay(
                    // Moving highlight, clipped to the crown shape.
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.95), Color.white, Color.white.opacity(0.95), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: w * 0.55)
                        .offset(x: x * w)
                        .rotationEffect(.degrees(22))
                        .blendMode(.plusLighter)
                    }
                    .mask(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15, weight: .semibold))
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.35).opacity(glow), radius: 5)
        }
    }
}

// MARK: - Glass background helper
// Wraps iOS 26 Liquid Glass (.glassEffect) with a materials fallback for older SDKs.

extension View {
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(ChatTheme.violet.opacity(0.10)), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(ChatTheme.violet.opacity(0.06), in: shape)
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - CareerMode display helpers

extension CareerMode {
    var title: String {
        switch self {
        case .general:       return "General"
        case .resumeReview:  return "Resume"
        case .mockInterview: return "Interview"
        case .coverLetter:   return "Cover Letter"
        case .jdMatch:       return "JD Match"
        case .roadmap:       return "Roadmap"
        }
    }

    var icon: String {
        switch self {
        case .general:       return "message.fill"
        case .resumeReview:  return "doc.text.fill"
        case .mockInterview: return "mic.fill"
        case .coverLetter:   return "pencil.and.outline"
        case .jdMatch:       return "briefcase.fill"
        case .roadmap:       return "map.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .general:       return "Open-ended career questions"
        case .resumeReview:  return "ATS scoring & feedback on your resume"
        case .mockInterview: return "Practice interview questions"
        case .coverLetter:   return "Generate a tailored cover letter"
        case .jdMatch:       return "Match your profile to a job description"
        case .roadmap:       return "Plan your skill-building path"
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: RoleIQMessage
    var onCopy: (() -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil
    var onFeedback: ((Bool) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    
    @State private var showFeedbackToast = false
    @State private var showCopyToast = false
    @State private var copiedBlockID: String? = nil

    private var isEmptyStreaming: Bool { message.content.isEmpty && message.isStreaming }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if isEmptyStreaming {
                    TypingIndicator().padding(.horizontal, 14).padding(.vertical, 12)
                } else if message.isUser {
                    renderedContent(message.shownContent)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background { RoundedRectangle(cornerRadius: 16).fill(ChatTheme.primaryGradient) }
                        .contextMenu {
                            Button {
                                onEdit?()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                } else {
                    renderedContent(message.shownContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.trailing, 6)
                }

                if !message.isUser && !message.content.isEmpty && !message.isStreaming {
                    HStack(spacing: 16) {
                        Text(message.modelUsed)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ChatTheme.textSecondary)
                        Spacer()
                        iconButton(showCopyToast ? "checkmark" : "doc.on.doc") {
                            Haptics.success(); onCopy?(); flashCopyToast()
                        }
                        iconButton("arrow.counterclockwise") { Haptics.medium(); onRegenerate?() }
                        ShareLink(item: ChatViewModel.plainText(from: message.content)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13))
                                .foregroundStyle(ChatTheme.textSecondary)
                        }
                        iconButton(message.liked == true ? "hand.thumbsup.fill" : "hand.thumbsup") {
                            Haptics.success(); onFeedback?(true); flashToast()
                        }
                        iconButton(message.liked == false ? "hand.thumbsdown.fill" : "hand.thumbsdown") {
                            Haptics.tap(); onFeedback?(false)
                        }
                    }
                    .padding(.trailing, 20)
                    .overlay(alignment: .topLeading) {
                        if showFeedbackToast {
                            Text("Thanks for your feedback")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .offset(y: -22)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .overlay(alignment: .top) {
                        if showCopyToast {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("Copied!")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(ChatTheme.primaryGradient, in: Capsule())
                            .shadow(color: ChatTheme.violet.opacity(0.4), radius: 8, y: 3)
                            .offset(y: -26)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    private func iconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(ChatTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func flashToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFeedbackToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showFeedbackToast = false }
        }
    }

    private func flashCopyToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyToast = false }
        }
    }

    // MARK: Segmented rendering — plain text via markdown, fenced code in a box

    private enum Segment { case text(String), code(String, String?) }

    private func parseSegments(_ raw: String) -> [Segment] {
        var segments: [Segment] = []
        var buffer: [String] = [], codeBuffer: [String] = []
        var inCode = false, codeLang: String? = nil

        func flushText() { if !buffer.isEmpty { segments.append(.text(buffer.joined(separator: "\n"))); buffer = [] } }
        func flushCode() { segments.append(.code(codeBuffer.joined(separator: "\n"), codeLang)); codeBuffer = []; codeLang = nil }

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode { flushCode(); inCode = false }
                else {
                    flushText(); inCode = true
                    let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
            } else if inCode { codeBuffer.append(line) }
            else { buffer.append(line) }
        }
        if inCode { flushCode() }  // unterminated fence mid-stream
        flushText()
        return segments
    }

    //MARK: assistant font size & spacing
    @ViewBuilder
    private func renderedContent(_ raw: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parseSegments(raw).enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    renderedText(t, isEmpty: false)
                        .font(.system(size: 17, weight: .regular))
                        .lineSpacing(message.isUser ? 5 : 7)
                        .foregroundStyle(message.isUser ? .white : ChatTheme.textPrimary)
                case .code(let code, let lang):
                    let blockID = "\(lang ?? "code")-\(code.count)-\(code.prefix(12))"
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text((lang ?? "code").uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ChatTheme.textSecondary)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = code
                                Haptics.success()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    copiedBlockID = blockID
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { if copiedBlockID == blockID { copiedBlockID = nil } }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedBlockID == blockID ? "checkmark" : "doc.on.doc")
                                    Text(copiedBlockID == blockID ? "Copied" : "Copy")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(copiedBlockID == blockID ? ChatTheme.violet : ChatTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ChatTheme.textPrimary.opacity(0.04))

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(ChatTheme.textPrimary)
                                .textSelection(.enabled)
                                .padding(12)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChatTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
// MARK: - Markdown rendering

private func renderedText(_ raw: String, isEmpty: Bool) -> Text {
    if isEmpty { return Text(" ") }

    let cleaned = raw
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let stripped = trimmed.drop { $0 == "#" || $0 == " " }
                return "**\(stripped)**"
            }
            return String(line)
        }
        .joined(separator: "\n")

    if let attributed = try? AttributedString(
        markdown: cleaned,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    ) {
        return Text(attributed)
    }
    return Text(cleaned)
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(ChatTheme.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                withAnimation { phase = (phase + 1) % 3 }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ChatSessionEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let entity = ChatSessionEntity(mode: .mockInterview)
    container.mainContext.insert(entity)

    return NavigationStack {
        ChatView(entity: entity, isSidebarOpen: .constant(false))
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager())   // don't call .configure() here, preview only needs default state
}
