//
//  SavedJobsView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 13/08/26.
//



import SwiftUI
import SwiftData

struct SavedJobsView: View {
    enum Tab: String, CaseIterable { case favorites = "Favorites", bookmarks = "Saved" }

    @Query(sort: \SavedJob.savedAt, order: .reverse) private var saved: [SavedJob]
    @Environment(\.modelContext) private var context
    @State private var tab: Tab = .favorites

    private var shown: [SavedJob] {
        switch tab {
        case .favorites: return saved.filter { $0.isFavorite }
        case .bookmarks: return saved.filter { $0.isBookmarked }
        }
    }

    /// Swipe-remove. In Favorites, clears the favorite flag; in Saved, clears
    /// the bookmark flag. If both flags end up false, the record is deleted —
    /// same rule as the detail screen's toggles.
    private func remove(_ item: SavedJob) {
        Haptics.tap()
        withAnimation {
            switch tab {
            case .favorites:  item.isFavorite = false
            case .bookmarks:  item.isBookmarked = false
            }
            if !item.isFavorite && !item.isBookmarked {
                context.delete(item)
            }
            try? context.save()
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()

            VStack(spacing: 14) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: tab) { _, _ in
                    Haptics.tap()
                }

                if shown.isEmpty {
                    emptyState
                } else {
                    Text("Swipe a job left to remove it")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                    List {
                        ForEach(shown) { item in
                            ZStack {
                                savedCard(item)
                                NavigationLink {
                                    JobDetailView(job: item.asJob, currency: item.currencySymbol)
                                } label: { EmptyView() }
                                .opacity(0)   // hide the default chevron/row styling, keep the tap
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    remove(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Your jobs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: tab == .favorites ? "heart" : "bookmark")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textMuted)
            Text(tab == .favorites ? "No favorites yet" : "Nothing saved yet")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text(tab == .favorites
                 ? "Tap the heart on a job to keep it here."
                 : "Bookmark a job to apply later.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func savedCard(_ item: SavedJob) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if item.isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(AppTheme.danger).font(.caption)
                }
                if item.isBookmarked {
                    Image(systemName: "bookmark.fill").foregroundStyle(AppTheme.accent).font(.caption)
                }
            }
            Text(item.company)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accentSoft)
            if !item.location.isEmpty {
                Label(item.location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let salary = item.salaryText {
                Text(salary)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent.opacity(0.15), lineWidth: 1))
    }
}

// Rebuild a Job from a SavedJob so tapping a saved item reopens the detail screen.
private extension SavedJob {
    var asJob: Job {
        Job(
            id: jobID, title: title, company: company, location: location,
            description: jobDescription, url: url, salaryMin: salaryMin, salaryMax: salaryMax,
            salaryPredicted: salaryPredicted, contractType: contractType, category: category,
            created: createdISO
        )
    }
}
