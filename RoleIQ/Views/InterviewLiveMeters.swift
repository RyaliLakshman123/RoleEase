//
//  InterviewLiveMeters.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 29/08/26.
//


//
//  Drop-in additions to MockInterviewView: a live WPM meter with slow/good/fast
//  pace zones, and an answer timer with a filling ring. Both are driven entirely
//  in-view from signals that already exist (speech.transcript updates live via
//  SFSpeechRecognizer partial results; elapsed time from a start-stamp set when
//  recording begins). No ViewModel or backend changes required.


import SwiftUI

extension MockInterviewView {

    // MARK: Tunables

    /// Ideal interview pace band (words per minute).
    fileprivate var paceGoodLow: Double { 110 }
    fileprivate var paceGoodHigh: Double { 160 }
    /// Bar scale ceiling — WPM maps 0...this onto the bar width.
    fileprivate var paceScaleMax: Double { 220 }
    /// The ring fills over this many seconds; a gentle "you're long" cue.
    fileprivate var answerTargetSeconds: Double { 90 }

    // MARK: - Live meters container
    // Only meaningful while recording. Returns EmptyView otherwise so the layout
    // collapses cleanly and the orb status line can take the space instead.

    @ViewBuilder
    var liveMeters: some View {
        if speech.isRecording {
            TimelineView(.animation) { context in
                let elapsed = liveElapsed(now: context.date)
                let words = liveWordCount
                let wpm = liveWPM(words: words, elapsed: elapsed)

                HStack(spacing: 18) {
                    timerRing(elapsed: elapsed)
                    paceMeter(wpm: wpm, showValue: elapsed >= 3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Timer ring

    fileprivate func timerRing(elapsed: Double) -> some View {
        let progress = min(elapsed / answerTargetSeconds, 1.0)
        let over = elapsed > answerTargetSeconds

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    over
                    ? Color(red: 0.95, green: 0.65, blue: 0.35)          // gentle amber past target
                    : Color(red: 0.62, green: 0.42, blue: 1.0),          // violet
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)

            Text(timeString(elapsed))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 52, height: 52)
    }

    // MARK: - Pace meter (WPM + zone bar)

    fileprivate func paceMeter(wpm: Int, showValue: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(showValue ? "\(wpm)" : "—")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))
                    .contentTransition(.numericText())
                Text("wpm")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(showValue ? paceLabel(for: Double(wpm)) : "listening")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(paceLabelColor(for: Double(wpm), showValue: showValue))
                    .animation(.easeInOut(duration: 0.25), value: wpm)
            }

            paceBar(wpm: showValue ? Double(wpm) : 0)
        }
        .frame(minWidth: 150)
    }

    // A horizontal bar with a dim "good zone" band marked, and a fill that
    // tints green inside the band, violet outside.
    fileprivate func paceBar(wpm: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillFrac = min(wpm / paceScaleMax, 1.0)
            let zoneLow = paceGoodLow / paceScaleMax
            let zoneHigh = paceGoodHigh / paceScaleMax

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.10))

                // Good-zone band highlight
                Capsule()
                    .fill(Color(red: 0.40, green: 0.80, blue: 0.50).opacity(0.18))
                    .frame(width: w * (zoneHigh - zoneLow))
                    .offset(x: w * zoneLow)

                // Fill
                Capsule()
                    .fill(paceFillColor(for: wpm))
                    .frame(width: max(4, w * fillFrac))
                    .animation(.easeOut(duration: 0.25), value: fillFrac)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Live derivations

    /// Live elapsed seconds since recording began. 0 if not recording.
    fileprivate func liveElapsed(now: Date) -> Double {
        guard let start = recordingStartedAt else { return 0 }
        return max(0, now.timeIntervalSince(start))
    }

    /// Word count off the live partial transcript.
    fileprivate var liveWordCount: Int {
        speech.transcript
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .filter { !$0.isEmpty }
            .count
    }

    /// Live WPM. Guards the first moments so it doesn't flash a wild number.
    fileprivate func liveWPM(words: Int, elapsed: Double) -> Int {
        guard elapsed >= 1, words > 0 else { return 0 }
        return Int((Double(words) / elapsed) * 60.0)
    }

    // MARK: - Labels & colors

    fileprivate func paceLabel(for wpm: Double) -> String {
        if wpm <= 0 { return "listening" }
        if wpm < paceGoodLow { return "a bit slow" }
        if wpm > paceGoodHigh { return "slow down" }
        return "good pace"
    }

    fileprivate func paceLabelColor(for wpm: Double, showValue: Bool) -> Color {
        guard showValue, wpm > 0 else { return .white.opacity(0.4) }
        if wpm >= paceGoodLow && wpm <= paceGoodHigh {
            return Color(red: 0.45, green: 0.85, blue: 0.55)   // green — same as summary strengths
        }
        return Color(red: 0.95, green: 0.70, blue: 0.45)       // amber nudge
    }

    fileprivate func paceFillColor(for wpm: Double) -> Color {
        if wpm >= paceGoodLow && wpm <= paceGoodHigh {
            return Color(red: 0.45, green: 0.85, blue: 0.55)   // green in the zone
        }
        return Color(red: 0.62, green: 0.42, blue: 1.0)        // violet otherwise
    }

    fileprivate func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
