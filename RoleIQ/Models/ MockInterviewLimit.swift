//
//   MockInterviewLimit.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 16/09/26.
//


//
//  Client-side weekly cap for FREE users: one mock interview per 7 days.
//  This is a conversion surface, not server-side enforcement — a reinstall
//  resets it. The real per-user quota lands with auth; this is the friendly
//  front-end for it and the paywall trigger, matching FreeMessageLimit's role.
//

import Foundation

enum MockInterviewLimit {
    /// Free users get one mock interview per rolling 7-day window.
    static let weeklyLimit = 1
    private static let windowDays = 7

    private static let countKey = "mockInterviewsUsedThisWeek"
    private static let windowStartKey = "mockInterviewWeekStart"

    /// Sessions started in the current 7-day window (auto-resets when the
    /// window has elapsed).
    static var usedThisWeek: Int {
        rolloverIfNeeded()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static var hasReachedLimit: Bool { usedThisWeek >= weeklyLimit }

    /// Days remaining until the free interview resets. 0 if already available.
    static var daysUntilReset: Int {
        rolloverIfNeeded()
        guard let start = UserDefaults.standard.object(forKey: windowStartKey) as? Date else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, windowDays - elapsed)
    }

    /// Call once per session actually started (i.e. when startSession()
    /// succeeds and moves to .inProgress) — not on every JD paste attempt.
    static func increment() {
        rolloverIfNeeded()
        let next = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(next, forKey: countKey)
    }

    /// Zero the count and start a fresh window if 7+ days have passed since
    /// the window began.
    private static func rolloverIfNeeded() {
        let now = Date()
        guard let start = UserDefaults.standard.object(forKey: windowStartKey) as? Date else {
            // First ever use — start the window now.
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
