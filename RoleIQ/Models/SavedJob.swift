//
//  SavedJob.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 13/08/26.
//


import Foundation
import SwiftData

/// A job the user has favorited (heart) and/or bookmarked (save / apply later).
/// One record per Adzuna job id; the two flags are independent so a job can be
/// hearted, bookmarked, or both. When both flags go false, the record is deleted.
@Model
final class SavedJob {
    /// Adzuna job id — unique per saved job so we never duplicate.
    @Attribute(.unique) var jobID: String

    var title: String
    var company: String
    var location: String
    var jobDescription: String
    var url: String
    var salaryText: String?
    var currencySymbol: String
    var createdISO: String

    // Raw fields preserved so a reopened saved job shows correct salary/type/category.
    var salaryMin: Double?
    var salaryMax: Double?
    var salaryPredicted: Bool = false
    var contractType: String?
    var category: String?

    var isFavorite: Bool
    var isBookmarked: Bool
    var savedAt: Date

    init(
        jobID: String,
        title: String,
        company: String,
        location: String,
        jobDescription: String,
        url: String,
        salaryText: String?,
        currencySymbol: String = "₹",
        createdISO: String,
        salaryMin: Double? = nil,
        salaryMax: Double? = nil,
        salaryPredicted: Bool = false,
        contractType: String? = nil,
        category: String? = nil,
        isFavorite: Bool = false,
        isBookmarked: Bool = false,
        savedAt: Date = .now
    ) {
        self.jobID = jobID
        self.title = title
        self.company = company
        self.location = location
        self.jobDescription = jobDescription
        self.url = url
        self.salaryText = salaryText
        self.currencySymbol = currencySymbol
        self.createdISO = createdISO
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.salaryPredicted = salaryPredicted
        self.contractType = contractType
        self.category = category
        self.isFavorite = isFavorite
        self.isBookmarked = isBookmarked
        self.savedAt = savedAt
    }

    /// Build from a decoded `Job`.
    convenience init(from job: Job, currency: String = "₹", isFavorite: Bool = false, isBookmarked: Bool = false) {
        self.init(
            jobID: job.id,
            title: job.title,
            company: job.company,
            location: job.location,
            jobDescription: job.description,
            url: job.url,
            salaryText: job.salaryText(currency: currency),
            currencySymbol: currency,
            createdISO: job.created,
            salaryMin: job.salaryMin,
            salaryMax: job.salaryMax,
            salaryPredicted: job.salaryPredicted,
            contractType: job.contractType,
            category: job.category,
            isFavorite: isFavorite,
            isBookmarked: isBookmarked
        )
    }
}
