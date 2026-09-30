//
//  SignInView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import SwiftUI
import AuthenticationServices
import UIKit

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var appear = false
    @State private var logoRotate = false
    @State private var featureAppear = [false, false, false]
    @State private var glowPulse = false
    @State private var shimmerPhase: CGFloat = -1

    private let features = [
        ("doc.text.magnifyingglass", "AI Resume Analysis", "Instant ATS scoring & feedback"),
        ("mic.fill", "Mock Interviews", "Realistic practice with voice AI"),
        ("map.fill", "Career Roadmap", "Personalized path to your goals")
    ]

    var body: some View {
        ZStack {
            background

            AnimatedParticles()

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                logo

                titleBlock
                    .padding(.top, 20)

                Spacer(minLength: 26)

                featureList
                    .padding(.horizontal, 22)

                Spacer(minLength: 24)

                signInBlock

                Spacer(minLength: 20)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Background
    private var background: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            AnimatedParticles()
        }
    }

    // MARK: - Logo

    private var logo: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
                .frame(width: 118, height: 118)
                .rotationEffect(.degrees(logoRotate ? 360 : 0))
                .animation(.linear(duration: 22).repeatForever(autoreverses: false), value: logoRotate)

            Circle()
                .fill(AppTheme.accent.opacity(0.2))
                .frame(width: 100, height: 100)
                .blur(radius: 18)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.accentGradient)
                .frame(width: 78, height: 78)
                .shadow(color: AppTheme.accent.opacity(0.55), radius: 22, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .overlay(shimmerSweep.mask(RoundedRectangle(cornerRadius: 24, style: .continuous)))

            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(appear ? 1 : 0.75)
        .opacity(appear ? 1 : 0)
    }

    private var shimmerSweep: some View {
        LinearGradient(
            colors: [.clear, Color.white.opacity(0.35), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(width: 30)
        .rotationEffect(.degrees(20))
        .offset(x: shimmerPhase * 90)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("RoleEase")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(0.3)

            Text("Your AI career coach")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(AppTheme.accentSoft.opacity(0.6))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .padding(.top, 2)
            .opacity(0.7)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, item in
                let (icon, title, subtitle) = item
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.22), AppTheme.accent.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSoft)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.accentSoft.opacity(0.55))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )
                .opacity(featureAppear[index] ? 1 : 0)
                .offset(x: featureAppear[index] ? 0 : -18)
            }
        }
    }

    // MARK: - Sign in

    private var signInBlock: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                authViewModel.handleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.accent.opacity(0.25), radius: 18, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            Text("OR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .tracking(1)
                .padding(.vertical, 2)

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                authViewModel.continueAsGuest()
            } label: {
                Text("Continue without signing in")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            
//            orDivider
//
//            Button {
//                let generator = UIImpactFeedbackGenerator(style: .medium)
//                generator.impactOccurred()
//                authViewModel.handleGoogleSignIn() // TODO: implement via GoogleSignIn SDK
//            } label: {
//                HStack(spacing: 10) {
//                    GoogleLogoView()
//                        .frame(width: 18, height: 18)
//                    Text("Continue with Google")
//                        .font(.system(size: 15.5, weight: .semibold))
//                        .foregroundStyle(AppTheme.textPrimary)
//                }
//                .frame(maxWidth: .infinity)
//                .frame(height: 54)
//                .background(
//                    RoundedRectangle(cornerRadius: 16, style: .continuous)
//                        .fill(.ultraThinMaterial)
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16, style: .continuous)
//                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
//                )
//            }
//            .buttonStyle(PressableButtonStyle())

            if let error = authViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("By continuing, you agree to our **Terms of Service** and **Privacy Policy**.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, AppTheme.textMuted.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .tracking(1)
            LinearGradient(colors: [AppTheme.textMuted.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Animation sequencing

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.7)) {
            appear = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.05)) {
            logoRotate = true
        }
        glowPulse = true

        for i in features.indices {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.35 + Double(i) * 0.1)) {
                featureAppear[i] = true
            }
        }

        withAnimation(.easeInOut(duration: 2.4).delay(0.9).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}

// MARK: - Pressable button style with subtle scale + fade

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Simplified multicolor Google "G" mark
// Swap for the official Google asset before shipping if strict brand compliance is needed.

private struct GoogleLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.24)
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), style: StrokeStyle(lineWidth: 3.4, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0.25, to: 0.49)
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), style: StrokeStyle(lineWidth: 3.4, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0.50, to: 0.74)
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), style: StrokeStyle(lineWidth: 3.4, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0.75, to: 0.99)
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), style: StrokeStyle(lineWidth: 3.4, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Rectangle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: 8, height: 3.4)
                .offset(x: 3.5)
        }
    }
}

// MARK: - Ambient floating particles for extra depth

private struct FloatingParticles: View {
    private let particles: [(size: CGFloat, x: CGFloat, delay: Double, duration: Double)] = (0..<14).map { _ in
        (
            size: CGFloat.random(in: 2...4),
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...4),
            duration: Double.random(in: 7...13)
        )
    }

    @State private var rise = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                Circle()
                    .fill(AppTheme.accentSoft.opacity(0.5))
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x * geo.size.width, y: rise ? -20 : geo.size.height + 20)
                    .animation(
                        .linear(duration: p.duration)
                        .repeatForever(autoreverses: false)
                        .delay(p.delay),
                        value: rise
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { rise = true }
    }
}

#Preview {
    SignInView()
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
