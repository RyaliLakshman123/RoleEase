//
//  JobsDashboardView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//



import Foundation
import SwiftUI
import SwiftData

struct JobsDashboardView: View {
    @StateObject private var viewModel = JobsViewModel()
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient.ignoresSafeArea()

                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    loadingState
                } else if let error = viewModel.errorMessage, viewModel.jobs.isEmpty {
                    errorState(error)
                } else if viewModel.jobs.isEmpty && viewModel.hasSearched && !viewModel.showBrowsingUI {
                    emptyState
                } else {
                    jobsContent
                }
            }
            .navigationDestination(for: Job.self) { job in
                JobDetailView(job: job, currency: viewModel.currencySymbol)
            }
            .navigationTitle("Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if viewModel.jobs.isEmpty { await viewModel.loadJobs() }
            }
        }
    }

    // MARK: - Content

    private var jobsContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 1).id("top")

                    header
                    quickSearchChips
                    locationField
                    dateFilterChips

                    if viewModel.totalCount > 0 {
                        HStack {
                            Text("\(viewModel.totalCount.formatted()) jobs found")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(viewModel.jobs) { job in
                            jobCard(job)
                        }

                        if !viewModel.jobs.isEmpty {
                            pagerBar
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: viewModel.page) { _, _ in
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
        }
    }

    // MARK: - Header (greeting)

    @ViewBuilder
    private var header: some View {
        if viewModel.isSearchExpanded {
            expandedSearchBar
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Find your next role")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        searchIconButton
                        NavigationLink {
                            SavedJobsView()
                        } label: {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.accentSoft)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(AppTheme.surface.opacity(0.7)))
                                .overlay(Circle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 1))
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            Haptics.tap()
                        })
                    }
                    countryButton
                }
            }
        }
    }

    private var searchIconButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.isSearchExpanded = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentSoft)
                .frame(width: 42, height: 42)
                .background(Circle().fill(AppTheme.surface.opacity(0.7)))
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 1))
        }
    }

    private var expandedSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.accentSoft)
                TextField("Role, skill, or title", text: $viewModel.keyword)
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Haptics.tap()
                        Task { await viewModel.loadJobs() }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.isSearchExpanded = false
                        }
                    }
            }
            .padding(12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
            )

            Button("Cancel") {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.isSearchExpanded = false
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accentSoft)
        }
    }
    private var countryButton: some View {
        Menu {
            ForEach(AdzunaCountry.all) { c in
                Button {
                    Haptics.tap()
                    Task { await viewModel.setCountry(c) }
                } label: {
                    if c == viewModel.country {
                        Label("\(c.flag)  \(c.name)", systemImage: "checkmark")
                    } else {
                        Text("\(c.flag)  \(c.name)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.country.flag)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppTheme.surface.opacity(0.7)))
            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 1))
        }
    }

    private var greeting: String {
        let timeGreeting: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default:      timeGreeting = "Good evening"
        }
        if let name = authViewModel.userName, !name.isEmpty {
            let first = name.split(separator: " ").first.map(String.init) ?? name
            return "\(timeGreeting), \(first)"
        }
        return timeGreeting
    }

    // MARK: - Quick-search chips

    private var quickSearchChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickSearches, id: \.self) { term in
                    let selected = viewModel.keyword == term
                    Button {
                        Haptics.tap()
                        Task { await viewModel.runQuickSearch(term) }
                    } label: {
                        Text(term)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selected ? Color.white : AppTheme.accentSoft)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(selected ? AppTheme.accent : AppTheme.surface))
                            .overlay(
                                Capsule().stroke(AppTheme.accent.opacity(selected ? 0 : 0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16) // aligns first/last chip with the rest of the page
        }
        // Cancel the parent's 16pt padding so chips scroll off the true screen edge.
        .padding(.horizontal, -16)
    }

    // MARK: - Date filter chips

    private var dateFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateFilter.allCases) { filter in
                    let selected = viewModel.dateFilter == filter
                    Button {
                        Haptics.tap()
                        Task { await viewModel.setDateFilter(filter) }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selected ? Color.white : AppTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected ? AppTheme.accent : AppTheme.surface)
                            )
                            .overlay(
                                Capsule().stroke(AppTheme.accent.opacity(selected ? 0 : 0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    // MARK: - Pager bar (one segmented control: ‹  Page X of Y  ›, middle taps to jump)

    private var pagerBar: some View {
        HStack(spacing: 0) {
            pagerArrow(system: "chevron.left", enabled: viewModel.canGoPrevious) {
                Task { await viewModel.previousPage() }
            }

            Divider().frame(height: 22).overlay(AppTheme.accent.opacity(0.15))

            Menu {
                ForEach(viewModel.pageNumbers, id: \.self) { n in
                    Button {
                        Haptics.tap()
                        Task { await viewModel.goToPage(n) }
                    } label: {
                        if n == viewModel.page {
                            Label("Page \(n)", systemImage: "checkmark")
                        } else {
                            Text("Page \(n)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.pageLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(viewModel.isLoading)
            .simultaneousGesture(TapGesture().onEnded {
                Haptics.tap()
            })

            Divider().frame(height: 22).overlay(AppTheme.accent.opacity(0.15))

            pagerArrow(system: "chevron.right", enabled: viewModel.canGoNext) {
                Task { await viewModel.nextPage() }
            }
        }
        .background(AppTheme.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func pagerArrow(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Color.white : AppTheme.textMuted)
                .frame(width: 52, height: 46)
                .background(enabled ? AppTheme.accent.opacity(0.9) : Color.clear)
        }
        .disabled(!enabled || viewModel.isLoading)
    }

    // MARK: - Location field

    private var locationField: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundStyle(AppTheme.accent)
            TextField("Location", text: $viewModel.location)
                .foregroundStyle(AppTheme.textPrimary)
                .autocapitalization(.none)
                .onSubmit { Task { await viewModel.loadJobs() } }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Job card

    private func jobCard(_ job: Job) -> some View {
        NavigationLink(value: job) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(job.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }

                Text(job.company)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accentSoft)

                HStack(spacing: 12) {
                    Label(job.location, systemImage: "mappin.and.ellipse")
                    if !job.postedDate.isEmpty {
                        Label(job.postedDate, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                if let salary = job.salaryText(currency: viewModel.currencySymbol) {
                    Text(salary + (job.salaryPredicted ? " (est.)" : ""))
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accentSoft)
                }

                Text(job.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading state (Render cold-start can take ~50s on first search)

    private var loadingState: some View {
        VStack(spacing: 12) {
            LottieView(name: "JobsSearchLoader")
                .scaledToFit()
                .frame(height: 260)
            Text("Finding roles for you…")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, -90)
            Text("The first search can take a moment while we warm up.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, -70)
        }
    }
    

    // MARK: - Empty state (search ran, zero results — e.g. no jobs posted in-window)

    private var emptyState: some View {
        VStack(spacing: 8) {
            LottieView(name: "NoJobsAnimation")
                .scaledToFit()
                .frame(height: 250)
                .padding(.horizontal, 40)
            Text("No jobs found")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, -50)
            Text("Nothing matches this search in \(viewModel.lastSearchedCountry.name) for the selected time range. Try a wider range or a different city.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, -20)
            Button {
                Haptics.tap()
                Task {
                    if viewModel.dateFilter == .month {
                        await viewModel.resetSearch()      // already widest — start over
                    } else {
                        await viewModel.setDateFilter(.month)
                    }
                }
            } label: {
                Text(viewModel.dateFilter == .month ? "Reset search" : "Try “Past month”")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentSoft)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.16)))
                    .overlay(Capsule().stroke(AppTheme.accent.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textMuted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadJobs() }
            }
            .foregroundStyle(AppTheme.accent)
        }
        .padding()
    }
}


#Preview {
    JobsDashboardView()
        .environment(AuthViewModel())
        .modelContainer(for: SavedJob.self, inMemory: true)
        .preferredColorScheme(.dark)
}
