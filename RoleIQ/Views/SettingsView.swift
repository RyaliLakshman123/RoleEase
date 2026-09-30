//
//  SettingsView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 30/08/26.
//




//
//  App settings, presented as a bottom sheet from the ChatHistorySidebar's
//  gear button (via ChatContainer's `showSettings`). Black→violet gradient
//  background and glass surfaces to match the rest of the app.
//
//  Layout, top to bottom:
//    • Hero header — large avatar, name, sign-in status.
//    • Pro upgrade card — the one place violet is allowed to be loud, since
//      it's the primary conversion surface (goes live with the paywall).
//    • Grouped rows — Account, Preferences, Support, About — as glass cards
//      with hairline dividers, matching the reference screenshots' grouping.
//    • Log Out — destructive, set apart at the bottom.
//
//  Every interactive element fires a Haptics call, consistent with the app.
//
//  Runtime wiring notes:
//  • Name + logout read from AuthViewModel (real). Email isn't shown because
//    Sign in with Apple only returns it on first sign-in and we don't persist
//    it — the header shows sign-in status instead.
//  • Subscription is hardcoded "Free" and Upgrade is a no-op for now; both
//    become real when the paywall ships (same moment interview isPro does).
//  • Privacy / Terms / Report currently show a "Coming Soon" alert. Uncomment
//    the URL-opening lines once those pages/routes exist (privacy and terms
//    are required for App Store submission regardless).
//


import SwiftUI
import RevenueCatUI
import SwiftData
import RevenueCat

struct SettingsView: View {

    // Account state comes from the shared auth object (same one RecruiterEmailView uses).
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    
    // Persisted user preference. Haptics.swift reads this key to gate feedback
    // app-wide; the default is registered as `true` in RoleIQApp.
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var showLogoutConfirm = false
    @State private var showComingSoon = false
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showNameEditor = false
    @State private var nameInput = ""
    @State private var showRestoreResult = false
    @State private var restoreResultMessage = ""
    
    private var displayName: String {
        (authViewModel.userName?.isEmpty == false) ? authViewModel.userName! : "Your Name"
    }

    // App version + build, pulled from the bundle so the About row is always accurate.
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteAllUserData() {
        do {
            try modelContext.delete(model: ChatSessionEntity.self)
            try modelContext.delete(model: SavedJob.self)
            try modelContext.delete(model: ATSHistoryItem.self)
            try modelContext.delete(model: InterviewSessionEntity.self)

            let resumes = try modelContext.fetch(
                FetchDescriptor<ResumeItem>()
            )

            for resume in resumes {
                modelContext.delete(resume)
            }

            try modelContext.save()

        } catch {
            print("Delete Account: data wipe error — \(error)")
        }

        UserDefaults.standard.removeObject(forKey: "recruiterEmailsUsedThisWeek")
        UserDefaults.standard.removeObject(forKey: "recruiterEmailWeekStart")
    }
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        heroHeader

                        if !subscriptionManager.isProUser {
                            upgradeCard
                        }

                        SettingsGroup(title: "Account") {
                            SettingsRow(icon: "sparkles", title: "Subscription",
                                        trailingText: subscriptionManager.isProUser ? "Pro" : "Free",
                                        showsChevron: !subscriptionManager.isProUser) {
                                Haptics.tap()
                                if !subscriptionManager.isProUser { showPaywall = true }
                            }
                            Divider().overlay(dividerTint)
                            SettingsRow(icon: "arrow.clockwise", title: "Restore Purchases") {
                                Haptics.tap()
                                Task {
                                    let restored = await subscriptionManager.restorePurchases()
                                    restoreResultMessage = restored
                                        ? "Your Pro access has been restored."
                                        : "No previous purchases found for this Apple ID."
                                    showRestoreResult = true
                                }
                            }
                            Divider().overlay(dividerTint)
                            SettingsRow(icon: "gearshape", title: "Manage Subscription") {
                                Haptics.tap()
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        SettingsGroup(title: "Preferences") {
                            hapticsToggleRow
                        }

                        SettingsGroup(title: "Support") {
                            SettingsRow(icon: "exclamationmark.bubble", title: "Report an Issue") {
                                Haptics.tap()
                                if let url = URL(string: "mailto:support@example.com?subject=RoleIQ%20Issue%20Report") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Divider().overlay(dividerTint)
                            SettingsRow(icon: "envelope", title: "Contact Us") {
                                Haptics.tap()
                                if let url = URL(string: "mailto:support@example.com") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        SettingsGroup(title: "About") {
                            SettingsRow(icon: "hand.raised", title: "Privacy Policy") {
                                Haptics.tap()
                                // TODO: uncomment once the page exists (required for submission).
                                 if let url = URL(string: "https://ryalilakshman.github.io/RoleIQ-privacy-policy/") {
                                     UIApplication.shared.open(url)
                                 }
                            }
                            Divider().overlay(dividerTint)
                            SettingsRow(icon: "doc.text", title: "Terms of Service") {
                                Haptics.tap()
                                // TODO: uncomment once the page exists (required for submission).
                                 if let url = URL(string: "https://ryalilakshman.github.io/RoleIQ-privacy-policy/terms.html") {
                                     UIApplication.shared.open(url)
                                 }
                            }
                            Divider().overlay(dividerTint)
                            SettingsRow(icon: "info.circle", title: "Version",
                                        trailingText: appVersion, showsChevron: false) {
                                Haptics.tap()
                            }
                        }

                        SettingsGroup(title: "Account Management") {
                            SettingsRow(icon: "trash", title: "Delete Account", showsChevron: false) {
                                Haptics.medium()
                                showDeleteConfirm = true
                            }
                        }

                        logoutButton
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 30, height: 30)
                            .glassBackground(in: Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
        .confirmationDialog("Log Out?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Haptics.medium()
                authViewModel.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) { Haptics.tap() }
        } message: {
            Text("You can sign back in anytime with Apple.")
        }
        .confirmationDialog("Delete Account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Haptics.medium()
                deleteAllUserData()
                authViewModel.deleteAccount()
                dismiss()
            }
            Button("Cancel", role: .cancel) { Haptics.tap() }
        } message: {
            Text("This permanently erases your chats, saved jobs, resume history, sent emails, and interview sessions. This can't be undone.")
        }
        .alert("Restore Purchases", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) { Haptics.tap() }
        } message: {
            Text(restoreResultMessage)
        }
//        .alert("Coming Soon", isPresented: $showComingSoon) {
//            Button("OK", role: .cancel) { Haptics.tap() }
//        } message: {
//            Text("This arrives with the next update.")
//        }
        .sheet(isPresented: $showNameEditor) {
            NameEditSheet()
                .environment(authViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in
                    showPaywall = false
                }
                .onRestoreCompleted { customerInfo in
                    let hasPro = customerInfo.entitlements.active["RoleIQ Pro"] != nil
                    restoreResultMessage = hasPro
                        ? "Your Pro access has been restored."
                        : "No previous purchases found for this Apple ID."
                    showPaywall = false
                    showRestoreResult = true
                }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        VStack(spacing: 14) {
            // Avatar with a soft violet halo — the one bit of glow up top,
            // kept low-opacity so it reads premium rather than loud.
            AvatarRingView(
                initials: AvatarGenerator.initials(for: authViewModel.userName ?? "?"),
                colorHex: authViewModel.effectiveAvatarHex,
                size: 88,
                isPro: subscriptionManager.isProUser
            )
            

            VStack(spacing: 4) {
                Button {
                    Haptics.tap()
                    showNameEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSoft)
                    }
                }
                .buttonStyle(PressableStyle())
                
                    .onTapGesture {
                        Haptics.tap()
                        nameInput = authViewModel.userName ?? ""
                        showNameEditor = true
                    }

                HStack(spacing: 5) {
                    Image(systemName: authViewModel.isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                        .font(.system(size: 12))
                    // Sign in with Apple only returns the email on first sign-in
                    // and we don't persist it, so we show status here.
                    Text(authViewModel.isSignedIn ? "Signed in with Apple" : "Not signed in")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Upgrade card
    // The primary conversion surface, so this is where violet is allowed to
    // carry real weight — a gradient wash, crown, and clear value line.

private var upgradeCard: some View {
    Button {
        Haptics.medium()
        showPaywall = true
    } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Pro")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Smarter answers, faster interviews")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accentGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Haptics toggle row

    private var hapticsToggleRow: some View {
        HStack(spacing: 14) {
            RowIcon("hand.tap.fill")
            Text("Haptic Feedback")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Toggle("", isOn: $hapticsEnabled)
                .labelsHidden()
                .tint(AppTheme.accent)
                .onChange(of: hapticsEnabled) { _, isOn in
                    if isOn { Haptics.tap() }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Log out

    private var logoutButton: some View {
        Button {
            Haptics.medium()
            showLogoutConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(AppTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .glassBackground(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var dividerTint: Color { Color.white.opacity(0.06) }
}

// MARK: - Grouped glass card
// Wraps a set of rows in one continuous glass surface so dividers read as
// hairlines inside a card, matching the reference screenshots' grouping.
// The optional header uses the same bold-uppercase-tracked label style as the
// "QUESTION n OF m" caption on the interview screen, tying the screens together.

private struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .glassBackground(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Reusable row
// Leading icon badge, title, optional trailing text, optional chevron.
// Designed to sit inside a SettingsGroup (no own background) so several rows
// share one glass card divided by hairlines.

private struct SettingsRow: View {
    let icon: String
    let title: String
    var trailingText: String? = nil
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RowIcon(icon)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Row icon badge
// Small tinted violet square behind each glyph — the consistent, subtle
// accent that ties the rows together without shouting.

private struct RowIcon: View {
    let systemName: String
    init(_ systemName: String) { self.systemName = systemName }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: 30, height: 30)
            .background(
                AppTheme.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

// MARK: - Pressable style
// Gentle scale + dim on press so every tappable surface feels responsive,
// matching the tactile feel the haptics already give.

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .environmentObject(SubscriptionManager())
}
