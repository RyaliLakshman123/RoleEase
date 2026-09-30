////
////  ATSScoreCard.swift
////  RoleEase
////
////  Created by Lakshman Ryali on 25/08/26.
////
//
//
//
//import SwiftUI
//
//struct ATSScoreCard: View {
//    let result: ATSScoreResult
//
//    // Drives the entrance animation for both the arc and the bar.
//    @State private var animateIn = false
//
//    private let violet = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
//
//    var body: some View {
//        VStack(spacing: 22) {
//            meterRow
//            if !result.verdict.isEmpty { verdictBlock }
//            keywordSection
//            if !result.suggestions.isEmpty { suggestionsSection }
//        }
//        .padding(20)
//        .background(
//            RoundedRectangle(cornerRadius: 22, style: .continuous)
//                .fill(Color.white.opacity(0.04))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 22, style: .continuous)
//                        .stroke(violet.opacity(0.22), lineWidth: 1)
//                )
//        )
//        .onAppear {
//            withAnimation(.easeOut(duration: 1.1)) { animateIn = true }
//        }
//    }
//
//    // MARK: - Top row: arc meter + match bar
//
//    private var meterRow: some View {
//        HStack(spacing: 20) {
//            arcMeter
//            VStack(alignment: .leading, spacing: 10) {
//                Text("ATS SCORE")
//                    .font(.system(size: 11, weight: .bold))
//                    .tracking(2)
//                    .foregroundStyle(.white.opacity(0.45))
//                matchBar
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//    }
//
//    private var arcMeter: some View {
//        let fraction = CGFloat(min(100, max(0, result.atsScore))) / 100
//
//        return ZStack {
//            Circle()
//                .trim(from: 0, to: 0.75)
//                .stroke(Color.white.opacity(0.08),
//                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
//                .rotationEffect(.degrees(135))
//
//            Circle()
//                .trim(from: 0, to: (animateIn ? fraction : 0) * 0.75)
//                .stroke(
//                    AngularGradient(
//                        colors: [violet.opacity(0.6), violet, Color(red: 0.75, green: 0.6, blue: 1.0)],
//                        center: .center
//                    ),
//                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
//                )
//                .rotationEffect(.degrees(135))
//                .shadow(color: violet.opacity(0.6), radius: 8)
//
//            VStack(spacing: 0) {
//                Text("\(result.atsScore)")
//                    .font(.system(size: 34, weight: .bold, design: .rounded))
//                    .foregroundStyle(.white)
//                    .contentTransition(.numericText())
//                Text("/ 100")
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundStyle(.white.opacity(0.4))
//            }
//        }
//        .frame(width: 116, height: 116)
//    }
//
//    private var matchBar: some View {
//        let fraction = CGFloat(min(100, max(0, result.matchPercent))) / 100
//
//        return VStack(alignment: .leading, spacing: 6) {
//            HStack(alignment: .firstTextBaseline, spacing: 4) {
//                Text("\(result.matchPercent)%")
//                    .font(.system(size: 24, weight: .bold, design: .rounded))
//                    .foregroundStyle(.white)
//                Text("role match")
//                    .font(.system(size: 13))
//                    .foregroundStyle(.white.opacity(0.5))
//            }
//
//            GeometryReader { geo in
//                ZStack(alignment: .leading) {
//                    Capsule().fill(Color.white.opacity(0.08))
//                    Capsule()
//                        .fill(
//                            LinearGradient(
//                                colors: [violet, Color(red: 0.75, green: 0.6, blue: 1.0)],
//                                startPoint: .leading, endPoint: .trailing
//                            )
//                        )
//                        .frame(width: (animateIn ? fraction : 0) * geo.size.width)
//                        .shadow(color: violet.opacity(0.5), radius: 6)
//                }
//            }
//            .frame(height: 10)
//        }
//    }
//
//    // MARK: - Verdict
//
//    private var verdictBlock: some View {
//        HStack(alignment: .top, spacing: 10) {
//            Image(systemName: "sparkles")
//                .font(.system(size: 14))
//                .foregroundStyle(violet)
//                .padding(.top, 2)
//            Text(result.verdict)
//                .font(.system(size: 15, weight: .medium))
//                .foregroundStyle(.white.opacity(0.9))
//                .fixedSize(horizontal: false, vertical: true)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                .fill(violet.opacity(0.12))
//        )
//    }
//
//    // MARK: - Keywords
//
//    private var keywordSection: some View {
//        VStack(alignment: .leading, spacing: 14) {
//            if !result.matchedKeywords.isEmpty {
//                chipGroup(
//                    title: "MATCHED",
//                    systemImage: "checkmark.circle.fill",
//                    tint: Color(red: 0.3, green: 0.85, blue: 0.55),
//                    keywords: result.matchedKeywords
//                )
//            }
//            if !result.missingKeywords.isEmpty {
//                chipGroup(
//                    title: "MISSING",
//                    systemImage: "exclamationmark.circle.fill",
//                    tint: Color(red: 1.0, green: 0.55, blue: 0.4),
//                    keywords: result.missingKeywords
//                )
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//
//    private func chipGroup(
//        title: String,
//        systemImage: String,
//        tint: Color,
//        keywords: [String]
//    ) -> some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Label(title, systemImage: systemImage)
//                .font(.system(size: 11, weight: .bold))
//                .tracking(1.5)
//                .foregroundStyle(tint)
//
//            FlowLayout(spacing: 8, lineSpacing: 8) {
//                ForEach(keywords, id: \.self) { word in
//                    Text(word)
//                        .font(.system(size: 13, weight: .medium))
//                        .foregroundStyle(.white.opacity(0.85))
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 6)
//                        .background(
//                            Capsule().fill(tint.opacity(0.15))
//                                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
//                        )
//                }
//            }
//        }
//    }
//
//    // MARK: - Suggestions
//
//    private var suggestionsSection: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text("HOW TO IMPROVE")
//                .font(.system(size: 11, weight: .bold))
//                .tracking(1.5)
//                .foregroundStyle(.white.opacity(0.45))
//
//            ForEach(Array(result.suggestions.enumerated()), id: \.offset) { _, suggestion in
//                HStack(alignment: .top, spacing: 10) {
//                    Circle()
//                        .fill(violet)
//                        .frame(width: 6, height: 6)
//                        .padding(.top, 6)
//                    Text(suggestion)
//                        .font(.system(size: 14))
//                        .foregroundStyle(.white.opacity(0.8))
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//}
//
//// MARK: - Simple wrapping layout for keyword chips (iOS 16+)
//
//struct FlowLayout: Layout {
//    var spacing: CGFloat = 8
//    var lineSpacing: CGFloat = 8
//
//    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
//        let maxWidth = proposal.width ?? .infinity
//        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
//        for view in subviews {
//            let size = view.sizeThatFits(.unspecified)
//            if x + size.width > maxWidth, x > 0 {
//                x = 0
//                y += rowHeight + lineSpacing
//                rowHeight = 0
//            }
//            x += size.width + spacing
//            rowHeight = max(rowHeight, size.height)
//        }
//        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
//    }
//
//    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
//        for view in subviews {
//            let size = view.sizeThatFits(.unspecified)
//            if x + size.width > bounds.maxX, x > bounds.minX {
//                x = bounds.minX
//                y += rowHeight + lineSpacing
//                rowHeight = 0
//            }
//            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
//            x += size.width + spacing
//            rowHeight = max(rowHeight, size.height)
//        }
//    }
//}
//
//#Preview {
//    ZStack {
//        LinearGradient(
//            colors: [.black, Color(red: 0.16, green: 0.06, blue: 0.26)],
//            startPoint: .top, endPoint: .bottom
//        ).ignoresSafeArea()
//        ScrollView {
//            ATSScoreCard(result: .sample).padding()
//        }
//    }
//    .preferredColorScheme(.dark)
//}
