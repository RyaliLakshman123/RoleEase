//
//  Haptics.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//



import UIKit

enum Haptics {

    // Single source of truth for the toggle. Read fresh on every call so the
    // Settings switch takes effect immediately (no cached value, no restart).
    // Defaults to true via UserDefaults.register(defaults:) in RoleIQApp.init().
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
