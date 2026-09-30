//
//  RoleIQMessage.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//



import Foundation

// MARK: - AI Model
// Free  → Groq 70B      (isPro = false, sent to backend)  -- fast, decent quality
// Pro   → Gemini Flash  (isPro = true,  sent to backend)  -- better quality, gated behind Pro
enum RoleIQModel: String, CaseIterable, Codable {
    case free = "Groq 70B"
    case pro  = "Gemini Flash"

    // What users SEE. Never expose the provider name (rawValue is kept only for
    // Codable stability / backend logic).
    var displayName: String {
        switch self {
        case .free: return "RoleIQ"
        case .pro:  return "RoleIQ Pro"
        }
    }

    var isPro: Bool {
        switch self {
        case .free: return false
        case .pro:  return true
        }
    }

    var icon: String {
        switch self {
        case .free: return "bolt.fill"
        case .pro:  return "cpu.fill"
        }
    }

    var badge: String {
        switch self {
        case .free: return "Free"
        case .pro:  return "Pro"
        }
    }
}

// MARK: - Career Context
// Tells the backend which system prompt / mode to use
enum CareerMode: String, Codable {
    case general        = "general"
    case resumeReview   = "resume_review"
    case mockInterview  = "mock_interview"
    case coverLetter    = "cover_letter"
    case jdMatch        = "jd_match"
    case roadmap        = "career_roadmap"
}

// MARK: - Message Model
struct RoleIQMessage: Identifiable, Codable, Equatable {
    let id:        UUID
    let content:   String        // full text sent to the model (may include hidden attachment text)
    let isUser:    Bool
    let timestamp: Date
    let modelUsed: String
    let mode:      CareerMode
    var isStreaming: Bool
    var liked:     Bool?      // nil = no feedback yet, true = 👍, false = 👎

    // Optional cleaned-up text to SHOW in the bubble instead of `content`.
    // Used so an attached file's raw extracted text stays hidden — the bubble
    // shows only what the user typed plus a small "📎 label". When nil, the UI
    // falls back to `content`.
    var displayContent: String?

    init(
        id:             UUID        = UUID(),
        content:        String,
        isUser:         Bool,
        timestamp:      Date        = Date(),
        modelUsed:      String      = RoleIQModel.free.displayName,
        mode:           CareerMode  = .general,
        isStreaming:    Bool        = false,
        liked:          Bool?       = nil,
        displayContent: String?     = nil
    ) {
        self.id             = id
        self.content        = content
        self.isUser         = isUser
        self.timestamp      = timestamp
        self.modelUsed      = modelUsed
        self.mode           = mode
        self.isStreaming    = isStreaming
        self.liked          = liked
        self.displayContent = displayContent
    }

    /// What the UI should render in the bubble.
    var shownContent: String { displayContent ?? content }

    var wireMessage: [String: String] {
        ["role": isUser ? "user" : "assistant", "content": content]
    }
}

// MARK: - Chat Session (persistence unit)
struct RoleIQChatSession: Identifiable, Codable {
    let id:        UUID
    let title:     String
    let preview:   String
    let timestamp: Date
    let messages:  [RoleIQMessage]
    let mode:      CareerMode

    init(messages: [RoleIQMessage], mode: CareerMode = .general) {
        self.id        = UUID()
        self.mode      = mode
        self.timestamp = Date()
        self.messages  = messages

        let firstUser  = messages.first(where: { $0.isUser })?.content ?? "New Chat"
        self.title     = String(firstUser.prefix(50))

        let last       = messages.last?.content ?? ""
        self.preview   = String(last.prefix(120))
    }

    var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: timestamp, relativeTo: Date())
    }

    var modeLabel: String {
        switch mode {
        case .general:       return "General"
        case .resumeReview:  return "Resume Review"
        case .mockInterview: return "Mock Interview"
        case .coverLetter:   return "Cover Letter"
        case .jdMatch:       return "JD Match"
        case .roadmap:       return "Career Roadmap"
        }
    }

    var modeIcon: String {
        switch mode {
        case .general:       return "message.fill"
        case .resumeReview:  return "doc.text.fill"
        case .mockInterview: return "mic.fill"
        case .coverLetter:   return "pencil.and.outline"
        case .jdMatch:       return "briefcase.fill"
        case .roadmap:       return "map.fill"
        }
    }
}



// MARK: - Backend mode key mapping
// routes/chat.js's MODE_PROMPTS keys are NOT the same strings as CareerMode's
// rawValue, so this maps one to the other. Without this, every non-general
// mode silently falls back to the general prompt server-side.
extension CareerMode {
    var backendKey: String {
        switch self {
        case .general:       return "general"
        case .resumeReview:  return "resume"
        case .mockInterview: return "interview"
        case .coverLetter:   return "coverLetter"
        case .jdMatch:       return "jobMatch"
        case .roadmap:       return "general" // ⚠️ no backend prompt for "roadmap" yet — see note below
        }
    }
}


enum ModelTier: String, CaseIterable, Codable {
    case light, medium, hard

    var label: String {
        switch self {
        case .light:  return "Light"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var icon: String {
        switch self {
        case .light:  return "bolt"
        case .medium: return "bolt.badge.clock"
        case .hard:   return "brain.head.profile"
        }
    }
}

extension CareerMode {
    // Mirrors backend's modelTier.js MODE_TIERS — used as the starting
    // point when a mode is picked; user can override from there.
    var defaultTier: ModelTier {
        switch self {
        case .general, .coverLetter:         return .light
        case .jdMatch:                        return .medium
        case .resumeReview, .mockInterview:   return .hard
        case .roadmap:                         return .light
        }
    }
}
