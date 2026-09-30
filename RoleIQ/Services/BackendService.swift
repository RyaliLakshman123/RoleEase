//
//  BackendService.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//


import Foundation
import SwiftUI

// MARK: - Backend Service (Render)

class BackendService {
    static let shared = BackendService()

    private let baseURL = "https://RoleIQ-backend.onrender.com"

    enum BackendError: Error {
        case badResponse
        case rateLimited
        case parsingFailed
        case serverError(String)
    }

    func generateEmailDraft(
        recruiterEmail: String,
        companyName: String,
        roleTitle: String,
        jobDescription: String,
        resumeSummary: String,
        userName: String,
        tone: String
    ) async throws -> RecruiterEmailDraft {
        let url = URL(string: "\(baseURL)/api/email/draft")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let body: [String: Any] = [
            "recruiterEmail": recruiterEmail,
            "companyName": companyName,
            "roleTitle": roleTitle,
            "jobDescription": jobDescription,
            "resumeSummary": resumeSummary,
            "userName": userName,
            "tone": tone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.badResponse
        }

        if httpResponse.statusCode == 429 {
            throw BackendError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw BackendError.serverError(message ?? "Server error")
        }

        guard
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let subject = parsed["subject"] as? String,
            let bodyText = parsed["body"] as? String
        else {
            throw BackendError.parsingFailed
        }

        return RecruiterEmailDraft(subject: subject, body: bodyText)
    }
}
