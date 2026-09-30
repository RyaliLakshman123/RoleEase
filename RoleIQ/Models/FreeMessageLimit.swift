//
//  FreeMessageLimit.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 03/09/26.
//


//  Client-side daily message counter for FREE users. Resets at local midnight.
//  This is a conversion surface, not server-side enforcement — a reinstall or
//  clock change resets it. The real per-user quota lands with auth; this is the
//  friendly front-end for it and the paywall trigger.
//

import Foundation

enum FreeMessageLimit {
    /// Messages a free user may send per calendar day.
    static let dailyLimit = 10

    private static let countKey = "freeMessageCount"
    private static let dateKey  = "freeMessageCountDate"

    /// Messages sent today (auto-resets when the local day changes).
    static var sentToday: Int {
        rolloverIfNeeded()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static var remaining: Int { max(0, dailyLimit - sentToday) }
    static var hasReachedLimit: Bool { sentToday >= dailyLimit }

    /// Call once per successfully-sent free message.
    static func increment() {
        rolloverIfNeeded()
        let next = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(next, forKey: countKey)
    }

    /// Zero the count if the stored day isn't today.
    private static func rolloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let stored = UserDefaults.standard.object(forKey: dateKey) as? Date
        if stored == nil || Calendar.current.startOfDay(for: stored!) != today {
            UserDefaults.standard.set(0, forKey: countKey)
            UserDefaults.standard.set(today, forKey: dateKey)
        }
    }
}
