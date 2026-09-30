//
//  AvatarRingView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 20/09/26.
//


import SwiftUI

struct AvatarRingView: View {
    let initials: String
    let colorHex: String
    var size: CGFloat = 88
    var showRing: Bool = true
    var isPro: Bool = false

    var body: some View {
        ZStack {
            if showRing {
                RotatingArcRing(size: size * 1.4, lineWidth: 3, isPro: isPro)
                    .allowsHitTesting(false)
            }

            Circle()
                .fill(AvatarGenerator.gradient(hex: colorHex))
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

            // Pro crown badge — sits at the top of the avatar, gold on a dark chip.
            if isPro {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
                    .padding(size * 0.09)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .overlay(Circle().stroke(AppTheme.gold.opacity(0.6), lineWidth: 1))
                    .offset(y: -size * 0.52)
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }
}

#Preview {
    ZStack {
        AppTheme.screenGradient.ignoresSafeArea()
        AvatarRingView(initials: "R", colorHex: "8B5CF6")
    }
}



// MARK: - Style 1: Rotating gradient arc
// A single glowing arc that sweeps around the avatar. Subtle, premium.

struct RotatingArcRing: View {
    var size: CGFloat = 120
    var lineWidth: CGFloat = 3
    var isPro: Bool = false
    @State private var rotate = false

    private var arcColors: [Color] {
        isPro
            ? [AppTheme.gold.opacity(0), AppTheme.gold, AppTheme.goldSoft]
            : [AppTheme.accent.opacity(0), AppTheme.accent, AppTheme.accentSoft]
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.35)
            .stroke(
                AngularGradient(colors: arcColors, center: .center),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotate)
            .onAppear { rotate = true }
    }
}

// MARK: - Style 2: Two counter-rotating dashed rings
// Two dashed circles spinning opposite directions — more energetic, techy.

struct DualDashedRing: View {
    var size: CGFloat = 120
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AppTheme.accent.opacity(0.6),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 8])
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: spin)

            Circle()
                .stroke(
                    AppTheme.accentSoft.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 10])
                )
                .frame(width: size - 14, height: size - 14)
                .rotationEffect(.degrees(spin ? -360 : 0))
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: spin)
        }
        .onAppear { spin = true }
    }
}

// MARK: - Style 3: Pulsing glow halo
// A soft violet ring that breathes in and out. Calmest of the three.

struct PulsingHaloRing: View {
    var size: CGFloat = 120
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.accent.opacity(pulse ? 0.15 : 0.5), lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.08 : 0.96)

            Circle()
                .fill(AppTheme.accent.opacity(pulse ? 0.05 : 0.18))
                .frame(width: size, height: size)
                .blur(radius: 12)
                .scaleEffect(pulse ? 1.15 : 0.95)
        }
        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Preview — all three around a sample avatar, side by side

#Preview {
    ZStack {
        AppTheme.screenGradient.ignoresSafeArea()

        HStack(spacing: 36) {
            avatarWith(RotatingArcRing(size: 116), label: "Arc")
            avatarWith(DualDashedRing(size: 116), label: "Dashed")
            avatarWith(PulsingHaloRing(size: 116), label: "Halo")
        }
    }
}

@ViewBuilder
private func avatarWith<R: View>(_ ring: R, label: String) -> some View {
    VStack(spacing: 12) {
        ZStack {
            ring
            Circle()
                .fill(AvatarGenerator.gradient(hex: "8B5CF6"))
                .frame(width: 88, height: 88)
                .overlay(Text("R").font(.system(size: 32, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        Text(label).font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
    }
}

#Preview("Pro vs Free") {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 40) {
            AvatarRingView(initials: "L", colorHex: "8B5CF6", size: 96, isPro: false)
            AvatarRingView(initials: "L", colorHex: "8B5CF6", size: 96, isPro: true)
        }
    }
}
