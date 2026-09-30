//
//  RoleIQApp.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

//MARK: RootView launch flow is bypassed — restore before archive.

import SwiftUI
import SwiftData

@main
struct RoleIQApp: App {

    @StateObject private var subscriptionManager: SubscriptionManager

    init() {
        // Haptics on by default; the Settings toggle can turn them off.
        UserDefaults.standard.register(defaults: ["hapticsEnabled": true])

        let manager = SubscriptionManager()
        manager.configure()

        _subscriptionManager = StateObject(wrappedValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptionManager)
                .task {
                    await subscriptionManager.loadCustomerInfo()
                    await subscriptionManager.loadOfferings()
                    // Warm the Render backend so first chat/regen isn't a cold start.
                    var req = URLRequest(url: URL(string: "https://RoleIQ-backend.onrender.com/api/chat")!)
                    req.httpMethod = "GET"
                    req.timeoutInterval = 5
                    _ = try? await URLSession.shared.data(for: req)
                }
        }
        .modelContainer(for: [
            ResumeItem.self,
            ChatSessionEntity.self,
            SavedJob.self,
            ATSHistoryItem.self,
            InterviewSessionEntity.self,
            SentEmailEntity.self
        ])
    }
}
