//
//  SplashView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

//
//  SplashView.swift
//  RoleIQ
//
//  Created by Lakshman Ryali on 01/08/26.
//

import SwiftUI

struct SplashView: View {

    var onFinished: () -> Void = {}

    // ── Logo ──────────────────────────────────────────────
    @State private var logoScale: CGFloat        = 0.42
    @State private var logoOpacity: Double       = 0.0
    @State private var logoY: CGFloat            = 14
    @State private var logoBreathe: CGFloat      = 1.0
    @State private var logoTilt: Double          = 0.0

    // ── Icon inner glow ───────────────────────────────────
    @State private var iconGlowOpacity: Double   = 0.0

    // ── Orbital rings ──────────────────────────────────────
    @State private var ringRotation: Double      = 0
    @State private var ring2Rotation: Double     = 0
    @State private var ringScale: CGFloat        = 0.78
    @State private var ringOpacity: Double       = 0.0

    // ── Shimmer sweep on icon tile ────────────────────────
    @State private var shimmerX: CGFloat         = -160

    // ── Background mesh (drifting blobs) ──────────────────
    @State private var blob1Scale: CGFloat       = 0.88
    @State private var blob2Scale: CGFloat       = 0.92
    @State private var blob1Offset: CGSize       = .zero
    @State private var blob2Offset: CGSize       = .zero
    @State private var blob3Offset: CGSize       = .zero
    @State private var meshOpacity: Double       = 0.0

    // ── Title block ───────────────────────────────────────
    @State private var titleOpacity: Double      = 0.0
    @State private var titleY: CGFloat           = 18
    @State private var titleGlow: Double         = 0.0
    @State private var titleShimmerX: CGFloat    = -220

    // ── Tagline ───────────────────────────────────────────
    @State private var tagOpacity: Double        = 0.0
    @State private var tagY: CGFloat             = 12

    // ── Progress dots ──────────────────────────────────────
    @State private var dotsOpacity: Double       = 0.0
    @State private var dot1Scale: CGFloat        = 0.4
    @State private var dot2Scale: CGFloat        = 0.4
    @State private var dot3Scale: CGFloat        = 0.4
    @State private var activeDot: Int            = 0

    // ── Progress bar ────────────────────────────────────────
    @State private var progressOpacity: Double   = 0.0
    @State private var progressFill: CGFloat     = 0.0

    // ── Loading label ───────────────────────────────────────
    @State private var loadingOpacity: Double    = 0.0
    @State private var loadingText: String       = "Preparing your coach…"

    // ── Skip button ───────────────────────────────────────
    @State private var skipOpacity: Double       = 0.0

    // ── Particles + sparkles ───────────────────────────────
    @State private var particles: [Particle]     = Particle.generate(34)
    @State private var particleOpacity: Double   = 0.0
    @State private var sparkles: [Sparkle]       = Sparkle.generate(10)
    @State private var sparkleToggle: Bool       = false

    // ── Exit ──────────────────────────────────────────────
    @State private var exiting: Bool             = false

    // ── Palette ────────────────────────────────────────────
    private let bg          = Color(red: 0.039, green: 0.039, blue: 0.078)   // #0A0A14
    private let violet      = Color(red: 0.482, green: 0.361, blue: 0.941)   // #7B5CF0
    private let violetSoft  = Color(red: 0.624, green: 0.510, blue: 0.969)   // #9F82F7
    private let violetDeep  = Color(red: 0.278, green: 0.157, blue: 0.663)   // #4728A9
    private let pink        = Color(red: 0.831, green: 0.451, blue: 0.980)   // subtle accent for mesh
    private let textPri     = Color.white
    private let textSec     = Color(white: 0.72)
    private let textMuted   = Color(white: 0.44)

    private let loadingMessages = [
        "Preparing your coach…",
        "Warming up the AI…",
        "Almost there…"
    ]

    var body: some View {
        ZStack {
            // ── 1. Background ──────────────────────────
            backgroundLayer

            // ── 2. Ambient particles ───────────────────
            particleField
                .opacity(particleOpacity)

            // ── 3. Twinkling sparkles ───────────────────
            sparkleField

            // ── 4. Grain ───────────────────────────────
            grainLayer

            // ── 5. Vignette ─────────────────────────────
            vignetteLayer

            // ── 6. Content column ──────────────────────
            VStack(spacing: 0) {
                Spacer()

                logoCluster
                    .offset(y: logoY)

                VStack(spacing: 10) {
                    shimmeringTitle
                        .opacity(titleOpacity)
                        .offset(y: titleY)

                    Text("Your AI career coach")
                        .font(.system(size: 15, weight: .regular))
                        .tracking(0.2)
                        .foregroundStyle(textSec)
                        .opacity(tagOpacity)
                        .offset(y: tagY)
                }
                .padding(.top, 34)

                Spacer()

                // Loading label
                Text(loadingText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(textMuted)
                    .opacity(loadingOpacity)
                    .padding(.bottom, 14)
                    .animation(.easeInOut(duration: 0.3), value: loadingText)
                    .transition(.opacity)

                // Progress bar
                progressBar
                    .opacity(progressOpacity)
                    .padding(.horizontal, 90)
                    .padding(.bottom, 16)

                // Three progress dots
                dotsRow
                    .opacity(dotsOpacity)
                    .padding(.bottom, 30)

                // Skip pill
                skipPill
                    .opacity(skipOpacity)
                    .padding(.bottom, 52)
            }
        }
        .opacity(exiting ? 0 : 1)
        .scaleEffect(exiting ? 1.05 : 1)
        .animation(.easeInOut(duration: 0.55), value: exiting)
        .onAppear(perform: play)
    }

    // MARK: - Shimmering title

    private var shimmeringTitle: some View {
        Text("RoleIQ")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [textPri, violetSoft.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.85), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 90)
                    .offset(x: titleShimmerX)
                    .blendMode(.plusLighter)
                }
                .mask(
                    Text("RoleIQ")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .tracking(0.5)
                )
            )
            .shadow(color: violet.opacity(titleGlow), radius: 18)
    }

    // MARK: - Logo cluster

    private var logoCluster: some View {
        ZStack {
            // Outer diffuse glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [violet.opacity(0.38), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(blob1Scale)
                .opacity(iconGlowOpacity)
                .blendMode(.plusLighter)

            // Mid glow
            Circle()
                .fill(violetDeep.opacity(0.28))
                .frame(width: 170, height: 170)
                .blur(radius: 24)
                .scaleEffect(blob2Scale)
                .opacity(iconGlowOpacity)
                .blendMode(.plusLighter)

            // Outer orbital dashed ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            violetSoft.opacity(0.0),
                            violetSoft.opacity(0.65),
                            violetSoft.opacity(0.9),
                            violetSoft.opacity(0.65),
                            violetSoft.opacity(0.0)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.6, dash: [3, 9])
                )
                .frame(width: 172, height: 172)
                .rotationEffect(.degrees(ringRotation))
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Inner orbital dashed ring (counter-rotating)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [violet.opacity(0.0), violet.opacity(0.5), violet.opacity(0.0)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.2, dash: [2, 7])
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(ring2Rotation))
                .scaleEffect(ringScale)
                .opacity(ringOpacity * 0.85)

            // Static hairline ring
            Circle()
                .strokeBorder(violetSoft.opacity(0.18), lineWidth: 1)
                .frame(width: 132, height: 132)
                .scaleEffect(ringScale)
                .opacity(ringOpacity * 0.6)

            // Two orbiting glow dots, opposite phase
            Circle()
                .fill(violetSoft)
                .frame(width: 5, height: 5)
                .shadow(color: violetSoft, radius: 5)
                .offset(y: -86)
                .rotationEffect(.degrees(ringRotation))
                .opacity(ringOpacity)

            Circle()
                .fill(violet)
                .frame(width: 3.5, height: 3.5)
                .shadow(color: violet, radius: 4)
                .offset(y: -75)
                .rotationEffect(.degrees(ring2Rotation))
                .opacity(ringOpacity * 0.9)

            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(violet.opacity(0.45))
                    .frame(width: 114, height: 114)
                    .blur(radius: 20)
                    .offset(y: 10)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [violet.opacity(0.95), violetDeep.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 114, height: 114)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .white.opacity(0.25), radius: 6)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.0), .white.opacity(0.45), .white.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 114)
                    .offset(x: shimmerX)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .frame(width: 114, height: 114)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .rotation3DEffect(.degrees(logoTilt), axis: (x: 1, y: 1, z: 0))
            .scaleEffect(logoScale * logoBreathe)
            .opacity(logoOpacity)
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [violet, violetSoft],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressFill, height: 3)
                    .shadow(color: violet.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Three progress dots

    private var dotsRow: some View {
        HStack(spacing: 7) {
            dotCircle(index: 0, scale: dot1Scale)
            dotCircle(index: 1, scale: dot2Scale)
            dotCircle(index: 2, scale: dot3Scale)
        }
    }

    private func dotCircle(index: Int, scale: CGFloat) -> some View {
        Circle()
            .fill(violetSoft.opacity(activeDot == index ? 0.95 : 0.4))
            .frame(width: 6, height: 6)
            .scaleEffect(scale * (activeDot == index ? 1.25 : 1.0))
            .animation(.easeInOut(duration: 0.35), value: activeDot)
    }

    // MARK: - Skip pill

    private var skipPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            exit()
        } label: {
            HStack(spacing: 5) {
                Text("Skip")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(0.3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(textMuted)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Capsule().fill(Color.white.opacity(0.05))
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(SkipStyle())
    }

    // MARK: - Background (drifting mesh)

    private var backgroundLayer: some View {
        ZStack {
            bg.ignoresSafeArea()

            RadialGradient(
                colors: [violetDeep.opacity(0.55), .clear],
                center: .init(x: 0.18, y: 0.12),
                startRadius: 0,
                endRadius: 430
            )
            .offset(blob1Offset)
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .opacity(meshOpacity)

            RadialGradient(
                colors: [violet.opacity(0.32), .clear],
                center: .init(x: 0.88, y: 0.88),
                startRadius: 0,
                endRadius: 370
            )
            .offset(blob2Offset)
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .opacity(meshOpacity)

            RadialGradient(
                colors: [pink.opacity(0.16), .clear],
                center: .init(x: 0.82, y: 0.14),
                startRadius: 0,
                endRadius: 300
            )
            .offset(blob3Offset)
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .opacity(meshOpacity)

            RadialGradient(
                colors: [violetDeep.opacity(0.14), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 480
            )
            .ignoresSafeArea()
            .blendMode(.screen)
        }
    }

    // MARK: - Vignette

    private var vignetteLayer: some View {
        RadialGradient(
            colors: [.clear, bg.opacity(0.55)],
            center: .center,
            startRadius: 220,
            endRadius: 520
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Particle field

    private var particleField: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                Circle()
                    .fill(violetSoft.opacity(p.opacity))
                    .frame(width: p.size, height: p.size)
                    .blur(radius: p.blur)
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Sparkle field (twinkling four-point stars)

    private var sparkleField: some View {
        GeometryReader { geo in
            ForEach(sparkles) { s in
                SparkleShape()
                    .fill(Color.white.opacity(sparkleToggle ? s.maxOpacity : 0.05))
                    .frame(width: s.size, height: s.size)
                    .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                    .animation(
                        .easeInOut(duration: s.duration)
                        .repeatForever(autoreverses: true)
                        .delay(s.delay),
                        value: sparkleToggle
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { sparkleToggle = true }
    }

    // MARK: - Grain layer

    private var grainLayer: some View {
        Canvas { ctx, size in
            for _ in 0..<650 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let a = Double.random(in: 0.007...0.032)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .ignoresSafeArea()
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }

    // MARK: - Animation sequence

    private func play() {

        withAnimation(.easeOut(duration: 1.0)) {
            meshOpacity = 1.0
        }

        // Slow drifting mesh blobs
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            blob1Offset = CGSize(width: 18, height: -14)
        }
        withAnimation(.easeInOut(duration: 8.5).repeatForever(autoreverses: true).delay(0.4)) {
            blob2Offset = CGSize(width: -16, height: 12)
        }
        withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true).delay(0.8)) {
            blob3Offset = CGSize(width: -12, height: 10)
        }

        // 0 ms — logo springs in
        withAnimation(.spring(response: 0.72, dampingFraction: 0.62)) {
            logoScale   = 1.0
            logoOpacity = 1.0
            logoY       = 0
        }

        // Subtle continuous 3D tilt for depth
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true).delay(0.6)) {
            logoTilt = 6
        }
        // Gentle breathing after settle
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.9)) {
            logoBreathe = 1.035
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.08)) {
            iconGlowOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.18)) {
            ringOpacity = 1.0
            ringScale   = 1.0
        }

        withAnimation(.linear(duration: 16).repeatForever(autoreverses: false).delay(0.18)) {
            ringRotation = 360
        }
        withAnimation(.linear(duration: 11).repeatForever(autoreverses: false).delay(0.18)) {
            ring2Rotation = -360
        }

        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.2)) {
            blob1Scale = 1.14
        }
        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true).delay(0.5)) {
            blob2Scale = 1.08
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(0.4)) {
            titleGlow = 0.35
        }

        // Icon shimmer sweep
        withAnimation(.linear(duration: 0.001)) { shimmerX = -160 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerX = 160
            }
        }

        withAnimation(.easeIn(duration: 0.9).delay(0.12)) {
            particleOpacity = 1.0
        }

        // 340 ms — title
        withAnimation(.spring(response: 0.58, dampingFraction: 0.76).delay(0.34)) {
            titleOpacity = 1.0
            titleY       = 0
        }
        // Title shimmer sweep, repeating, starts a beat after title lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                titleShimmerX = 260
            }
        }

        // 460 ms — tagline
        withAnimation(.spring(response: 0.55, dampingFraction: 0.76).delay(0.46)) {
            tagOpacity = 1.0
            tagY       = 0
        }

        // 600 ms — loading label + progress bar
        withAnimation(.easeIn(duration: 0.35).delay(0.6)) {
            loadingOpacity = 1.0
            progressOpacity = 1.0
        }
        withAnimation(.linear(duration: 2.2).delay(0.6)) {
            progressFill = 1.0
        }

        // 680 ms — dots, staggered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            withAnimation(.easeIn(duration: 0.35)) { dotsOpacity = 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dot1Scale = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dot2Scale = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dot3Scale = 1.0 }
            }
        }

        // Cycle active dot + loading message
        for step in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(step) * 0.6) {
                activeDot = step
                loadingText = loadingMessages[step]
            }
        }

        // 900 ms — skip button
        withAnimation(.easeIn(duration: 0.45).delay(0.9)) {
            skipOpacity = 1.0
        }

        // Haptic on logo settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Auto-advance at 2.8 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            exit()
        }
    }

    private func exit() {
        guard !exiting else { return }
        exiting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onFinished()
        }
    }
}

// MARK: - Skip button style

private struct SkipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Four-point sparkle shape

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX, cy = rect.midY
        path.move(to: CGPoint(x: cx, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: cy), control: CGPoint(x: cx + w * 0.12, y: cy - h * 0.12))
        path.addQuadCurve(to: CGPoint(x: cx, y: rect.maxY), control: CGPoint(x: cx + w * 0.12, y: cy + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: cy), control: CGPoint(x: cx - w * 0.12, y: cy + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: cx, y: rect.minY), control: CGPoint(x: cx - w * 0.12, y: cy - h * 0.12))
        return path
    }
}

// MARK: - Particle model

private struct Particle: Identifiable {
    let id   = UUID()
    let x, y : CGFloat
    let size : CGFloat
    let opacity: Double
    let blur : CGFloat

    static func generate(_ n: Int) -> [Particle] {
        (0..<n).map { _ in
            Particle(
                x:       .random(in: 0.04...0.96),
                y:       .random(in: 0.04...0.96),
                size:    .random(in: 1.5...5.5),
                opacity: .random(in: 0.08...0.50),
                blur:    .random(in: 0.5...2.5)
            )
        }
    }
}

// MARK: - Sparkle model

private struct Sparkle: Identifiable {
    let id = UUID()
    let x, y: CGFloat
    let size: CGFloat
    let maxOpacity: Double
    let duration: Double
    let delay: Double

    static func generate(_ n: Int) -> [Sparkle] {
        (0..<n).map { _ in
            Sparkle(
                x: .random(in: 0.08...0.92),
                y: .random(in: 0.06...0.7),
                size: .random(in: 6...12),
                maxOpacity: .random(in: 0.25...0.55),
                duration: .random(in: 1.6...3.2),
                delay: .random(in: 0...2.5)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView()
}
