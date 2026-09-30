//
//  ChatSessionEntity.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 02/08/26.
//


import Foundation
import SwiftData

@Model
final class ChatSessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var preview: String
    var modeRaw: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool = false
    private var messagesData: Data

    init(title: String = "New Chat", mode: CareerMode = .general, messages: [RoleIQMessage] = [], pinned: Bool = false) {
        self.id = UUID()
        self.title = title
        self.preview = ""
        self.modeRaw = mode.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.pinned = pinned
        self.messagesData = (try? JSONEncoder().encode(messages)) ?? Data()
    }

    var mode: CareerMode {
        get { CareerMode(rawValue: modeRaw) ?? .general }
        set { modeRaw = newValue.rawValue }
    }

    /// Decodes/encodes on access. Fine for chat-length message lists;
    /// if history gets huge, switch to incremental SwiftData rows instead.
    var messages: [RoleIQMessage] {
        get { (try? JSONDecoder().decode([RoleIQMessage].self, from: messagesData)) ?? [] }
        set {
            messagesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
            // Use shownContent (displayContent ?? content) so an attachment's
            // raw "[Attached: …]" block never leaks into the sidebar title.
            if let firstUser = newValue.first(where: { $0.isUser }) {
                title = String(firstUser.shownContent.prefix(50))
            }
            if let last = newValue.last, !last.shownContent.isEmpty {
                preview = String(last.shownContent.prefix(120))
            }
        }
    }

    // MARK: - Display helpers
    // Used by the chat history sidebar cards so they can show a relative
    // timestamp, an SF Symbol, and a short label without duplicating logic.

    /// Relative time like "2h ago", "Just now", "3d ago".
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    /// SF Symbol for the session's CareerMode — matches the old card icons.
    var modeIcon: String {
        switch mode {
        case .general:       return "message"
        case .resumeReview:  return "doc.text"
        case .mockInterview: return "mic"
        case .coverLetter:   return "pencil"
        case .jdMatch:       return "briefcase"
        case .roadmap:       return "map"
        }
    }

    /// Short human label for the mode badge.
    var modeLabel: String {
        switch mode {
        case .general:       return "General"
        case .resumeReview:  return "Resume"
        case .mockInterview: return "Interview"
        case .coverLetter:   return "Cover Letter"
        case .jdMatch:       return "JD Match"
        case .roadmap:       return "Roadmap"
        }
    }
}
