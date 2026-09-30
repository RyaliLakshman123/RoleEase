//
//  InterviewSessionEntity.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 29/08/26.
//


//
//  SwiftData persistence unit for one completed mock interview. Mirrors
//  ChatSessionEntity's approach exactly: scalar metadata columns for listing
//  + a JSON blob for the rich payload (here, the SessionSummary). We DON'T
//  store audio — only the transcript/metrics/feedback that already live in
//  SessionSummary, plus the JD text so "Redo this JD" can re-run the role.
//
//  Registered in RoleIQApp's single .modelContainer array.
//

import Foundation
import SwiftData

@Model
final class InterviewSessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String            // derived: a short slug of the JD / role
    var jobDescription: String   // kept so the summary can offer "Redo this JD"
    var createdAt: Date
    var modelUsed: String        // "gemini" / "groq" — for a small badge if wanted
    private var summaryData: Data // JSON-encoded SessionSummary

    init(summary: SessionSummary, jobDescription: String) {
        self.id = UUID()
        self.jobDescription = jobDescription
        self.createdAt = Date()
        self.modelUsed = summary.modelUsed
        self.summaryData = (try? JSONEncoder().encode(summary)) ?? Data()
        self.title = Self.makeTitle(from: jobDescription, fallbackCount: summary.answers.count)
    }

    /// Decodes on access. Returns nil only if the blob is corrupt/empty.
    var summary: SessionSummary? {
        try? JSONDecoder().decode(SessionSummary.self, from: summaryData)
    }

    // MARK: - Display helpers (mirror ChatSessionEntity)

    /// Relative time like "2h ago", "Just now", "3d ago".
    var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: createdAt, relativeTo: Date())
    }

    /// A compact one-line title from the JD's first meaningful line, so the
    /// history row reads like "iOS Engineer at Acme" rather than a UUID.
    private static func makeTitle(from jd: String, fallbackCount: Int) -> String {
        let firstLine = jd
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
        if firstLine.isEmpty {
            return "Interview · \(fallbackCount) question\(fallbackCount == 1 ? "" : "s")"
        }
        return String(firstLine.prefix(50))
    }
}
