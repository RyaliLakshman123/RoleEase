//
//  BackendserviceAts.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 25/08/26.
//



import Foundation

extension BackendService {

    /// Scores a resume against a target role (and optional job description).
    /// - Parameter useGemini: when true, sends isPro=true so the backend uses
    ///   Gemini first. Defaults to true — Gemini gives better ATS judgment.
    func scoreResume(
        resumeText: String,
        jobRole: String,
        yearsOfExperience: Int,
        jobDescription: String? = nil,
        useGemini: Bool = true
    ) async throws -> ATSScoreResult {
        let url = URL(string: "\(APIConfig.baseURL)/api/resume/ats")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let jd = jobDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ATSScoreRequest(
            resumeText: resumeText,
            jobRole: jobRole,
            yearsOfExperience: max(0, yearsOfExperience),
            jobDescription: (jd?.isEmpty ?? true) ? nil : jd,
            isPro: useGemini
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BackendError.badResponse
        }
        if http.statusCode == 429 {
            throw BackendError.rateLimited
        }
        guard http.statusCode == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw BackendError.serverError(message ?? "Server error (\(http.statusCode))")
        }

        do {
            return try JSONDecoder().decode(ATSScoreResult.self, from: data)
        } catch {
            throw BackendError.parsingFailed
        }
    }
}
