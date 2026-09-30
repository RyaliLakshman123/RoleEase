//
//  ATSModels.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 25/08/26.
//


//
//  NOTE: We rely on Swift's *synthesized* Codable conformance — property names
//  match the JSON keys exactly, so no custom init(from:) or CodingKeys needed.
//  The backend already defaults every field, so missing keys are rare; where a
//  key might be absent, the property is optional or has a fallback via the
//  ATSScoreResult decoder below.
//

import Foundation

// MARK: - Request

struct ATSScoreRequest: Encodable {
    let resumeText: String
    let jobRole: String
    let yearsOfExperience: Int
    let jobDescription: String?   // optional — most accurate when provided
    let isPro: Bool               // true → backend uses Gemini first
}

// MARK: - Response pieces

/// Four-signal rubric, each 0...100.
struct ATSBreakdown: Codable, Equatable, Hashable {
    var keywords: Int = 0
    var formatting: Int = 0
    var impact: Int = 0
    var sections: Int = 0

    /// Ordered rows for the UI: (label, value).
    var rows: [(String, Int)] {
        [("Keywords", keywords), ("Formatting", formatting),
         ("Impact", impact), ("Sections", sections)]
    }
}

/// Readiness verdict label + tone the UI colors by.
struct ATSReadiness: Codable, Equatable, Hashable {
    var label: String = ""
    var tone: String = "mid"   // "high" | "good" | "mid" | "low"
}

/// A missing keyword plus where/how to add it.
struct ATSMissingKeyword: Codable, Equatable, Hashable, Identifiable {
    var id: String { keyword }
    var keyword: String = ""
    var placement: String = ""
}

// MARK: - Response

struct ATSScoreResult: Codable, Equatable, Hashable {
    var atsScore: Int = 0
    var matchPercent: Int = 0
    var readiness: ATSReadiness = ATSReadiness()
    var breakdown: ATSBreakdown = ATSBreakdown()
    var matchedKeywords: [String] = []
    var missingKeywords: [ATSMissingKeyword] = []
    var suggestions: [String] = []
    var verdict: String = ""
    var modelUsed: String = ""

    enum CodingKeys: String, CodingKey {
        case atsScore, matchPercent, readiness, breakdown,
             matchedKeywords, missingKeywords, suggestions, verdict, modelUsed
    }

    // Custom decoder so any missing key falls back to the defaults above,
    // instead of throwing. (Only ATSScoreResult needs this — the small structs
    // are always present as whole objects.)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        atsScore        = try c.decodeIfPresent(Int.self, forKey: .atsScore) ?? 0
        matchPercent    = try c.decodeIfPresent(Int.self, forKey: .matchPercent) ?? 0
        readiness       = try c.decodeIfPresent(ATSReadiness.self, forKey: .readiness) ?? ATSReadiness()
        breakdown       = try c.decodeIfPresent(ATSBreakdown.self, forKey: .breakdown) ?? ATSBreakdown()
        matchedKeywords = try c.decodeIfPresent([String].self, forKey: .matchedKeywords) ?? []
        missingKeywords = try c.decodeIfPresent([ATSMissingKeyword].self, forKey: .missingKeywords) ?? []
        suggestions     = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        verdict         = try c.decodeIfPresent(String.self, forKey: .verdict) ?? ""
        modelUsed       = try c.decodeIfPresent(String.self, forKey: .modelUsed) ?? ""
    }

    // Memberwise init for previews / samples.
    init(
        atsScore: Int, matchPercent: Int, readiness: ATSReadiness,
        breakdown: ATSBreakdown, matchedKeywords: [String],
        missingKeywords: [ATSMissingKeyword], suggestions: [String], verdict: String,
        modelUsed: String = ""
    ) {
        self.atsScore = atsScore; self.matchPercent = matchPercent
        self.readiness = readiness; self.breakdown = breakdown
        self.matchedKeywords = matchedKeywords; self.missingKeywords = missingKeywords
        self.suggestions = suggestions; self.verdict = verdict
        self.modelUsed = modelUsed
    }
}

extension ATSScoreResult {
    static let sample = ATSScoreResult(
        atsScore: 73,
        matchPercent: 78,
        readiness: ATSReadiness(label: "Almost there", tone: "good"),
        breakdown: ATSBreakdown(keywords: 80, formatting: 62, impact: 55, sections: 85),
        matchedKeywords: ["Swift", "SwiftUI", "UIKit", "Combine", "MVVM", "Git"],
        missingKeywords: [
            ATSMissingKeyword(keyword: "Unit testing", placement: "Add to Skills section"),
            ATSMissingKeyword(keyword: "CI/CD", placement: "Mention in a project bullet if you used it"),
            ATSMissingKeyword(keyword: "Core Data", placement: "Add to Skills if you've shipped with it")
        ],
        suggestions: [
            "Reformat headings so each section starts with a clear ATS-friendly label.",
            "Quantify your project bullets — add users, %, or scale.",
            "Add a dedicated Technical Skills section near the top."
        ],
        verdict: "Solid iOS fundamentals — tighten formatting and quantify results to clear more filters."
    )
}
