//
//  JobsViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//



import SwiftUI
import Combine


@MainActor
class JobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var totalCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasSearched = false
    @Published var showBrowsingUI = false   // forces the full layout (with search) over the empty state

    @Published var keyword = "developer"
    @Published var isSearchExpanded = false
    @Published var location: String
    @Published var dateFilter: DateFilter = .today
    @Published var country: AdzunaCountry
    @Published private(set) var lastSearchedCountry: AdzunaCountry

    @Published private(set) var page = 1
    @Published private(set) var totalPages = 1

    private let resultsPerPage = 20
    private var fetchTask: Task<Void, Never>?
    
    let quickSearches = [
        "iOS Developer", "Remote", "Data Analyst",
        "Backend", "Frontend", "Product Manager", "Designer"
    ]

    init() {
        // Auto-detect from the device region so a US user sees US jobs on launch.
        let detected = AdzunaCountry.detected()
        self.country = detected
        self.lastSearchedCountry = detected
        self.location = detected.defaultCity
    }

    var currencySymbol: String { country.currencySymbol }

    private var effectiveKeyword: String { keyword.isEmpty ? "developer" : keyword }
    private var effectiveLocation: String { location.isEmpty ? country.defaultCity : location }

    var canGoNext: Bool { page < totalPages }
    var canGoPrevious: Bool { page > 1 }
    var pageLabel: String { "Page \(page) of \(totalPages)" }
    var pageNumbers: [Int] { Array(1...max(totalPages, 1)) }

    // MARK: - Loading

    func loadJobs() async {
        await fetch(page: 1)
    }

    func nextPage() async {
        guard canGoNext else { return }
        await fetch(page: page + 1)
    }

    func previousPage() async {
        guard canGoPrevious else { return }
        await fetch(page: page - 1)
    }

    func goToPage(_ target: Int) async {
        guard target != page, target >= 1, target <= totalPages else { return }
        await fetch(page: target)
    }

    func setDateFilter(_ filter: DateFilter) async {
        dateFilter = filter
        await fetch(page: 1)
    }

    func runQuickSearch(_ term: String) async {
        keyword = term
        showBrowsingUI = false
        await fetch(page: 1)
    }
    
    /// Escape hatch from the empty state: restore defaults, show the full
    /// browsing layout (so the search bar is actually on screen), open it,
    /// and refetch. Even if the refetch is empty, the user stays on the
    /// browsing layout and can type a new search.
    func resetSearch() async {
        keyword = ""
        location = country.defaultCity
        dateFilter = .today
        showBrowsingUI = true
        isSearchExpanded = true
        await fetch(page: 1)
    }

    /// User picked a different country — reset the location to that country's
    /// default city and run a fresh search against the new index.
    func setCountry(_ newCountry: AdzunaCountry) async {
        country = newCountry
        location = newCountry.defaultCity
        await fetch(page: 1)
    }

    private func fetch(page targetPage: Int) async {
        // Cancel any in-flight fetch so a slower stale request can't overwrite
        // a newer one (this is what caused country/keyword changes to only take
        // effect on the second tap).
        fetchTask?.cancel()

        let task = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            hasSearched = true
            lastSearchedCountry = country

            // Snapshot the search parameters NOW, so an async delay can't let
            // them change under us mid-request.
            let kw = effectiveKeyword
            let loc = effectiveLocation
            let ctry = country.code
            let days = dateFilter.maxDaysOld

            do {
                let response = try await JobsService.shared.fetchJobs(
                    keyword: kw,
                    location: loc,
                    country: ctry,
                    page: targetPage,
                    results: resultsPerPage,
                    maxDaysOld: days
                )
                if Task.isCancelled { return }
                self.jobs = response.jobs.sorted {
                    ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
                }
                self.totalCount = response.count
                self.page = response.page
                self.totalPages = response.totalPages ?? max(Int(ceil(Double(response.count) / Double(resultsPerPage))), 1)
            } catch is CancellationError {
                return
            } catch JobsService.JobsError.rateLimited {
                errorMessage = "Job search is busy — try again in a minute."
            } catch {
                if Task.isCancelled { return }
                print("JOBS ERROR:", error)
                errorMessage = "Couldn't load jobs. Check your connection and try again."
            }
            isLoading = false
        }

        fetchTask = task
        await task.value
    }
}
