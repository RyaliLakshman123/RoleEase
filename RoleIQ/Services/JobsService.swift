//
//  JobsService.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//



import Foundation

class JobsService {
    static let shared = JobsService()

    enum JobsError: Error {
        case badResponse
        case rateLimited
        case parsingFailed
        case serverError(String)
    }

    /// Calls GET /api/jobs on your Render backend, scoped to a country.
    func fetchJobs(
        keyword: String,
        location: String,
        country: String,
        page: Int = 1,
        results: Int = 20,
        maxDaysOld: Int? = nil
    ) async throws -> JobsResponse {
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/jobs")!
        var items = [
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "results", value: String(results))
        ]
        if let maxDaysOld {
            items.append(URLQueryItem(name: "maxDaysOld", value: String(maxDaysOld)))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw JobsError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Render free tier sleeps after inactivity; cold start can take ~50s.
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JobsError.badResponse
        }

        if httpResponse.statusCode == 429 {
            throw JobsError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw JobsError.serverError(message ?? "Server error")
        }

        do {
            return try JSONDecoder().decode(JobsResponse.self, from: data)
        } catch {
            throw JobsError.parsingFailed
        }
    }
}
