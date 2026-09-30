//
//  Job.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//


import Foundation

// MARK: - Date filter (Phase 5, item 2)

enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Past week"
    case month = "Past month"

    var id: String { rawValue }

    /// Value sent to the backend as `maxDaysOld`.
    var maxDaysOld: Int {
        switch self {
        case .today: return 1
        case .week:  return 7
        case .month: return 30
        }
    }
}

// MARK: - Response

struct JobsResponse: Codable {
    let count: Int
    let page: Int
    let resultsPerPage: Int?
    let totalPages: Int?
    let hasMore: Bool?
    let jobs: [Job]

    enum CodingKeys: String, CodingKey {
        case count, page, resultsPerPage, totalPages, hasMore, jobs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count          = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        page           = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        resultsPerPage = try c.decodeIfPresent(Int.self, forKey: .resultsPerPage)
        totalPages     = try c.decodeIfPresent(Int.self, forKey: .totalPages)
        hasMore        = try c.decodeIfPresent(Bool.self, forKey: .hasMore)
        jobs           = try c.decodeIfPresent([Job].self, forKey: .jobs) ?? []
    }
}

// MARK: - Job

struct Job: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let company: String
    let location: String
    let description: String
    let url: String
    let salaryMin: Double?
    let salaryMax: Double?
    let salaryPredicted: Bool
    let contractType: String?
    let category: String?
    let created: String

    enum CodingKeys: String, CodingKey {
        case id, title, company, location, description, url
        case salaryMin, salaryMax, salaryPredicted, contractType, category, created
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // Adzuna returns `id` as either a String or a number — handle both.
        if let stringID = try? c.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? c.decode(Int.self, forKey: .id) {
            id = String(intID)
        } else {
            id = UUID().uuidString
        }

        title           = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        company         = try c.decodeIfPresent(String.self, forKey: .company) ?? ""
        location        = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        description     = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        url             = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        salaryMin       = try c.decodeIfPresent(Double.self, forKey: .salaryMin)
        salaryMax       = try c.decodeIfPresent(Double.self, forKey: .salaryMax)
        salaryPredicted = try c.decodeIfPresent(Bool.self, forKey: .salaryPredicted) ?? false
        contractType    = try c.decodeIfPresent(String.self, forKey: .contractType)
        category        = try c.decodeIfPresent(String.self, forKey: .category)
        // Never throws — backend guarantees a string, but stay defensive.
        created         = try c.decodeIfPresent(String.self, forKey: .created) ?? ""
    }

    /// Memberwise init — used to rebuild a Job from a stored SavedJob.
    init(
        id: String, title: String, company: String, location: String,
        description: String, url: String, salaryMin: Double?, salaryMax: Double?,
        salaryPredicted: Bool, contractType: String?, category: String?, created: String
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.description = description
        self.url = url
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.salaryPredicted = salaryPredicted
        self.contractType = contractType
        self.category = category
        self.created = created
    }

    /// Salary formatted in the given currency, e.g. "$80K – $120K", "₹8L – ₹12L".
    /// Uses Indian L/Cr grouping only for the rupee symbol; K/M elsewhere.
    func salaryText(currency: String = "₹") -> String? {
        func short(_ v: Double) -> String {
            if currency == "₹" {
                if v >= 10_000_000 { return "\(currency)\(trim(v / 10_000_000))Cr" }
                if v >= 100_000 { return "\(currency)\(trim(v / 100_000))L" }
                if v >= 1_000 { return "\(currency)\(trim(v / 1_000))K" }
                return "\(currency)\(Int(v))"
            } else {
                if v >= 1_000_000 { return "\(currency)\(trim(v / 1_000_000))M" }
                if v >= 1_000 { return "\(currency)\(trim(v / 1_000))K" }
                return "\(currency)\(Int(v))"
            }
        }
        func trim(_ v: Double) -> String {
            // "8" not "8.0", but keep "8.5"
            v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        }
        switch (salaryMin, salaryMax) {
        case let (min?, max?): return "\(short(min)) – \(short(max))"
        case let (min?, nil): return "\(short(min))+"
        case let (nil, max?): return "up to \(short(max))"
        default: return nil
        }
    }

    /// Backwards-compatible default (rupees). Prefer `salaryText(currency:)`.
    var salaryText: String? { salaryText(currency: "₹") }

    /// Parsed Date from the ISO `created` string (nil if empty/unparseable).
    var createdDate: Date? {
        guard !created.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: created) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: created)
    }

    /// "23 Jul 2026" from the ISO string; "" if parse fails.
    /// Adzuna sometimes returns a `created` slightly in the future (feed/timezone
    /// quirk) — clamp anything past "now" to today so we never show a future date.
    var postedDate: String {
        guard let date = createdDate else { return "" }
        let clamped = min(date, Date())
        let out = DateFormatter()
        out.dateFormat = "d MMM yyyy"
        return out.string(from: clamped)
    }
}
