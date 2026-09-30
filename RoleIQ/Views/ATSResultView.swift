//
//  ATSResultView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 25/08/26.
//


//
//  Dedicated results screen pushed after analysis completes. Same black-to-
//  violet design. The meter reveals first (score counts up, ring fills), then
//  the details settle in below. Back button + "Analyze another" both return
//  to the input screen.
//

import SwiftUI

struct ATSResultView: View {
    let result: ATSScoreResult
    /// Pops back to the input screen and clears the result so the user can run
    /// another check. Wired from ResumeUploadView.
    var onAnalyzeAnother: () -> Void

    // Sequenced entrance: meter first, then the rest fades up.
    @State private var showDetails = false

    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965)

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    CircularATSMeter(score: result.atsScore, matchPercent: result.matchPercent)
                        .padding(.top, 24)

                    if !result.readiness.label.isEmpty {
                        ReadinessBadge(readiness: result.readiness)
                    }

//                    if !result.modelUsed.isEmpty {
//                        analyzedByLine
//                    }

                    if showDetails {
                        detailStack
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Your ATS Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            // Let the meter animate alone for a beat, then bring in details.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.5)) { showDetails = true }
            }
        }
    }

//    private var analyzedByLine: some View {
//        // Friendly label: "Analyzed by Gemini" / "Analyzed by Groq".
//        let name: String = {
//            let m = result.modelUsed.lowercased()
//            if m.contains("gemini") { return "Gemini" }
//            if m.contains("groq") { return "Groq" }
//            return result.modelUsed
//        }()
//        return HStack(spacing: 6) {
//            Image(systemName: "sparkles")
//                .font(.system(size: 11))
//            Text("Analyzed by \(name)")
//                .font(.system(size: 12, weight: .medium))
//        }
//        .foregroundStyle(.white.opacity(0.4))
//    }

    private var detailStack: some View {
        VStack(spacing: 24) {
            if !result.verdict.isEmpty {
                Text(result.verdict)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            ATSBreakdownCard(breakdown: result.breakdown)
            ATSDetailCard(result: result)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAnalyzeAnother()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Analyze another")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(violet.opacity(0.5), lineWidth: 1))
                )
            }
            .padding(.top, 4)
        }
    }

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
}

// MARK: - Shared result components (used by ATSResultView)

struct CircularATSMeter: View {
    let score: Int
    let matchPercent: Int
    @State private var animateIn = false
    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965)

    private var fraction: CGFloat { CGFloat(min(100, max(0, score))) / 100 }
    private var scoreColor: Color {
        switch score {
        case ..<40:   return Color(red: 1.0, green: 0.5, blue: 0.42)
        case 40..<70: return Color(red: 1.0, green: 0.75, blue: 0.35)
        default:      return Color(red: 0.45, green: 0.85, blue: 0.6)
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: animateIn ? fraction : 0)
                    .stroke(
                        AngularGradient(colors: [scoreColor.opacity(0.7), scoreColor, violet],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.5), radius: 10)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).contentTransition(.numericText())
                    Text("ATS SCORE")
                        .font(.system(size: 11, weight: .bold)).tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 200, height: 200)

            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(violet)
                Text("\(matchPercent)% role match")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Capsule().fill(violet.opacity(0.15)))
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { animateIn = true } }
    }
}

struct ReadinessBadge: View {
    let readiness: ATSReadiness

    private var color: Color {
        switch readiness.tone {
        case "high": return Color(red: 0.45, green: 0.85, blue: 0.6)
        case "good": return Color(red: 0.55, green: 0.8, blue: 0.5)
        case "mid":  return Color(red: 1.0, green: 0.75, blue: 0.35)
        default:     return Color(red: 1.0, green: 0.5, blue: 0.42)
        }
    }
    private var icon: String {
        switch readiness.tone {
        case "high": return "checkmark.seal.fill"
        case "good": return "hand.thumbsup.fill"
        case "mid":  return "wrench.and.screwdriver.fill"
        default:     return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
            Text(readiness.label).font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            Capsule().fill(color.opacity(0.15))
                .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        )
    }
}

struct ATSBreakdownCard: View {
    let breakdown: ATSBreakdown
    @State private var animateIn = false
    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SCORE BREAKDOWN")
                .font(.system(size: 13, weight: .bold)).tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            ForEach(breakdown.rows, id: \.0) { label, value in
                barRow(label: label, value: value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(violet.opacity(0.2), lineWidth: 1))
        )
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { animateIn = true } }
    }

    private func color(for value: Int) -> Color {
        switch value {
        case ..<40:   return Color(red: 1.0, green: 0.5, blue: 0.42)
        case 40..<70: return Color(red: 1.0, green: 0.75, blue: 0.35)
        default:      return Color(red: 0.45, green: 0.85, blue: 0.6)
        }
    }

    private func barRow(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color(for: value))
                        .frame(width: (animateIn ? CGFloat(value) / 100 : 0) * geo.size.width)
                }
            }
            .frame(height: 8)
        }
    }
}

struct ATSDetailCard: View {
    let result: ATSScoreResult
    @State private var expandedKeyword: String?
    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !result.matchedKeywords.isEmpty { matchedGroup }
            if !result.missingKeywords.isEmpty { missingGroup }
            if !result.suggestions.isEmpty { suggestions }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(violet.opacity(0.2), lineWidth: 1))
        )
    }

    private var matchedGroup: some View {
        let tint = Color(red: 0.3, green: 0.85, blue: 0.55)
        return VStack(alignment: .leading, spacing: 10) {
            Label("MATCHED", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold)).tracking(1.5).foregroundStyle(tint)
            ATSFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(result.matchedKeywords, id: \.self) { word in
                    chip(text: word, tint: tint)
                }
            }
        }
    }

    private var missingGroup: some View {
        let tint = Color(red: 1.0, green: 0.55, blue: 0.4)
        return VStack(alignment: .leading, spacing: 10) {
            Label("MISSING — tap to see where to add", systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold)).tracking(1.5).foregroundStyle(tint)

            ATSFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(result.missingKeywords) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedKeyword = (expandedKeyword == item.keyword) ? nil : item.keyword
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(item.keyword)
                            if !item.placement.isEmpty {
                                Image(systemName: expandedKeyword == item.keyword
                                      ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .frame(maxWidth: 260, alignment: .leading)
                        // ← cap width so it can't overflow
                        .background(
                            Capsule().fill(tint.opacity(0.15))
                                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let key = expandedKeyword,
               let item = result.missingKeywords.first(where: { $0.keyword == key }),
               !item.placement.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12)).foregroundStyle(tint).padding(.top, 2)
                    Text(item.placement)
                        .font(.system(size: 15)).foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.1)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO IMPROVE")
                .font(.system(size: 13, weight: .bold)).tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            ForEach(Array(result.suggestions.enumerated()), id: \.offset) { _, s in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(violet).frame(width: 6, height: 6).padding(.top, 6)
                    Text(s).font(.system(size: 16)).foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func chip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.15))
                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1)))
    }
}

// MARK: - Wrapping layout (shared)

struct ATSFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + lineSpacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + lineSpacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        ATSResultView(result: .sample, onAnalyzeAnother: {})
    }
    .preferredColorScheme(.dark)
}
