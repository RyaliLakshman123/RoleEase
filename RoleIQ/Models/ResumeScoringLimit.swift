//
//  ResumeScoringLimit.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 16/09/26.
//


//
//  Client-side weekly cap for FREE users: one resume score per 7 days.
//  This is a conversion surface, not server-side enforcement — a reinstall
//  resets it. Mirrors MockInterviewLimit / FreeMessageLimit's pattern.
//

import Foundation

enum ResumeScoringLimit {
    /// Free users get one resume analysis per rolling 7-day window.
    static let weeklyLimit = 1
    private static let windowDays = 7

    private static let countKey = "resumeScoresUsedThisWeek"
    private static let windowStartKey = "resumeScoreWeekStart"

    /// Analyses run in the current 7-day window (auto-resets when elapsed).
    static var usedThisWeek: Int {
        rolloverIfNeeded()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static var hasReachedLimit: Bool { usedThisWeek >= weeklyLimit }

    /// Days remaining until the free score resets. 0 if already available.
    static var daysUntilReset: Int {
        rolloverIfNeeded()
        guard let start = UserDefaults.standard.object(forKey: windowStartKey) as? Date else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, windowDays - elapsed)
    }

    /// Call once per analysis that actually starts (i.e. a successful request
    /// is fired) — not on every button tap that fails validation.
    static func increment() {
        rolloverIfNeeded()
        let next = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(next, forKey: countKey)
    }

    private static func rolloverIfNeeded() {
        let now = Date()
        guard let start = UserDefaults.standard.object(forKey: windowStartKey) as? Date else {
            UserDefaults.standard.set(now, forKey: windowStartKey)
            return
        }
        let elapsedDays = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        if elapsedDays >= windowDays {
            UserDefaults.standard.set(0, forKey: countKey)
            UserDefaults.standard.set(now, forKey: windowStartKey)
        }
    }
}
