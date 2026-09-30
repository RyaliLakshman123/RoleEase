//
//  OnboardingView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 18/09/26.
//


import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "AI · CAREER · COACH",
            titleLines: ["Your career,", "supercharged."],
            subtitle: "One AI toolkit for every step — from a stronger resume to the offer.",
            features: [
                ("message.badge.filled.fill", "AI Career Chat", "Coaching that answers anything"),
                ("doc.text.magnifyingglass", "Resume Scoring", "Instant ATS feedback and fixes"),
                ("mic.fill", "Mock Interviews", "Practice out loud with voice AI")
            ]
        ),
        OnboardingPage(
            eyebrow: "FIND · MATCH · APPLY",
            titleLines: ["The right roles,", "found for you."],
            subtitle: "Search jobs, match your profile, and let AI write your outreach.",
            features: [
                ("briefcase.fill", "Job Search", "Live roles, saved in a tap"),
                ("envelope.fill", "Recruiter Emails", "AI drafts them, you send"),
                ("map.fill", "Career Roadmap", "A clear path to your goal")
            ]
        ),
        OnboardingPage(
            eyebrow: "PREP · PRACTICE · WIN",
            titleLines: ["Show up", "ready to win."],
            subtitle: "Walk into every interview prepared, confident, and one step ahead.",
            features: [
                ("checkmark.seal.fill", "Interview-Ready", "Rehearse real questions"),
                ("chart.line.uptrend.xyaxis", "Track Progress", "See yourself improve"),
                ("sparkles", "Stand Out", "Beat the applicant pile")
            ]
        )
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        OnboardingPageView(page: item, isActive: page == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                pageDots
                    .padding(.top, 4)

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background (glow + stars)

    private var background: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            AnimatedParticles()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? AppTheme.accent : Color.white.opacity(0.2))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
            }
        }
    }

    private var continueButton: some View {
        Button {
            Haptics.medium()
            if page < pages.count - 1 {
                withAnimation { page += 1 }
            } else {
                onFinish()
            }
        } label: {
            HStack(spacing: 8) {
                Text(page < pages.count - 1 ? "Continue" : "Get Started")
                    .font(.system(size: 17, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accentGradient)
                    .shadow(color: AppTheme.accent.opacity(0.5), radius: 18, y: 8)
            )
        }
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let eyebrow: String
    let titleLines: [String]
    let subtitle: String
    let features: [(String, String, String)]
}

// MARK: - Single page

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var contentAppear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            GlowingOrb()
                .frame(height: 210)

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Text(page.eyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(AppTheme.accentSoft)

                VStack(spacing: 2) {
                    ForEach(page.titleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
                    .padding(.top, 2)
            }
            .opacity(contentAppear ? 1 : 0)
            .offset(y: contentAppear ? 0 : 14)

            VStack(spacing: 10) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { i, f in
                    featureCard(icon: f.0, title: f.1, subtitle: f.2)
                        .opacity(contentAppear ? 1 : 0)
                        .offset(x: contentAppear ? 0 : -16)
                        .animation(.easeOut(duration: 0.4).delay(0.15 + Double(i) * 0.08), value: contentAppear)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)

            Spacer(minLength: 12)
        }
        .onAppear { if isActive { animate() } }
        .onChange(of: isActive) { _, active in
            if active { animate() } else { contentAppear = false }
        }
    }

    private func animate() {
        contentAppear = false
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) { contentAppear = true }
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.accentSoft)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Glowing orb (animated, matches the LociLearn hero)

private struct GlowingOrb: View {
    @State private var pulse = false
    @State private var rotate = false

    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(AppTheme.accent.opacity(0.35))
                .frame(width: 130, height: 130)
                .blur(radius: 40)
                .scaleEffect(pulse ? 1.15 : 0.9)

            // Lottie orb
            LottieView(name: "OnboardingLoader")
                .frame(width: 160, height: 160)

            // Rings (one pair only)
            Circle().stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: rotate)
            Circle().stroke(AppTheme.accent.opacity(0.12), lineWidth: 1)
                .frame(width: 175, height: 175)

            // Brain
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.accentSoft)
                .shadow(color: AppTheme.accent.opacity(0.6), radius: 10)
        }
        .onAppear {
            rotate = true
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Rising particles

private struct OnboardingParticles: View {

    private struct Particle {
        let size: CGFloat
        let x: CGFloat
        let delay: Double
        let duration: Double
        let opacity: Double
    }

    private let particles: [Particle] = (0..<30).map { _ in
        Particle(
            size: CGFloat.random(in: 2...4),
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...15),
            duration: Double.random(in: 8...16),
            opacity: Double.random(in: 0.2...0.6)
        )
    }

    var body: some View {

        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in

            Canvas { context, size in

                let currentTime = timeline.date.timeIntervalSinceReferenceDate

                for particle in particles {

                    let elapsed = currentTime + particle.delay
                    let progress = (elapsed.truncatingRemainder(
                        dividingBy: particle.duration
                    )) / particle.duration

                    let x = particle.x * size.width

                    let y = size.height + 20
                        - (size.height + 40) * progress

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    context.opacity = particle.opacity

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(AppTheme.accentSoft)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
#Preview {
    OnboardingView(onFinish: {})
}
