//
//  ATSHistoryItem.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 25/08/26.
//


//
//  SwiftData model for a saved ATS check. Stores the summary fields for the
//  history list plus the full ATSScoreResult (encoded as JSON) so tapping a row
//  can re-open the complete results screen. Encoding the whole result as data
//  keeps this robust if ATSScoreResult gains fields later.
//

import Foundation
import SwiftData

@Model
final class ATSHistoryItem {
    // Summary fields shown in the history list.
    var jobRole: String
    var atsScore: Int
    var matchPercent: Int
    var dateAdded: Date

    // Full result, JSON-encoded, for re-opening the detailed screen.
    var resultData: Data

    // The model that produced it ("gemini", "groq", etc.) — informational.
    var modelUsed: String

    init(
        jobRole: String,
        atsScore: Int,
        matchPercent: Int,
        modelUsed: String,
        resultData: Data,
        dateAdded: Date = .now
    ) {
        self.jobRole = jobRole
        self.atsScore = atsScore
        self.matchPercent = matchPercent
        self.modelUsed = modelUsed
        self.resultData = resultData
        self.dateAdded = dateAdded
    }
}

extension ATSHistoryItem {
    /// Build a history item from a fresh result. Returns nil if encoding fails.
    static func from(result: ATSScoreResult, jobRole: String, modelUsed: String) -> ATSHistoryItem? {
        guard let data = try? JSONEncoder().encode(result) else { return nil }
        return ATSHistoryItem(
            jobRole: jobRole.isEmpty ? "Untitled role" : jobRole,
            atsScore: result.atsScore,
            matchPercent: result.matchPercent,
            modelUsed: modelUsed,
            resultData: data
        )
    }

    /// Decode the stored full result to re-open the details screen.
    var decodedResult: ATSScoreResult? {
        try? JSONDecoder().decode(ATSScoreResult.self, from: resultData)
    }
}
