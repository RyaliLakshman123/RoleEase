//
//  JobDetailView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 13/08/26.
//


import SwiftUI
import SwiftData

struct JobDetailView: View {
    let job: Job
    var currency: String = "₹"

    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedJob]

    @State private var showSafari = false
    @State private var heartBounce = false
    @State private var toast: String?

    init(job: Job, currency: String = "₹") {
        self.job = job
        self.currency = currency
        let id = job.id
        _saved = Query(filter: #Predicate<SavedJob> { $0.jobID == id })
    }

    private var record: SavedJob? { saved.first }
    private var isFavorite: Bool { record?.isFavorite ?? false }
    private var isBookmarked: Bool { record?.isBookmarked ?? false }

    /// Prefer the currency stored on the saved record (so a job saved under $
    /// still shows $ even if the dashboard is now set to ₹). Falls back to the
    /// currency passed in from the dashboard for jobs that aren't saved.
    private var effectiveCurrency: String { record?.currencySymbol ?? currency }

    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metaGrid
                    statGrid
                    highlightsSection
                    descriptionSection
                    Color.clear.frame(height: 110) // room for the pinned action bar
                }
                .padding()
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                if let toast {
                    toastView(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
                actionBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: job.url) {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Text(monogram)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.accentSoft)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.company)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSoft)
                    if !job.location.isEmpty {
                        Text(job.location)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
            }

            Text(job.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var monogram: String {
        let letters = job.company.split(separator: " ").prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "•" : s
    }

    // MARK: - Meta chips (date / contract / category)

    private var metaGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !job.postedDate.isEmpty {
                    metaChip(icon: "calendar", text: job.postedDate)
                }
                if let contract = job.contractType, !contract.isEmpty {
                    metaChip(icon: "briefcase", text: contract.capitalized)
                }
                if let category = job.category, !category.isEmpty {
                    metaChip(icon: "square.grid.2x2", text: category)
                }
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppTheme.surface.opacity(0.7)))
            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Stat grid (2×2 tiles — always filled, never blank)

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(icon: "banknote.fill", label: "Salary", value: salaryValue)
            statTile(icon: "briefcase.fill", label: "Job type", value: jobTypeValue)
            statTile(icon: "square.grid.2x2.fill", label: "Category", value: job.category ?? "General")
            statTile(icon: "clock.fill", label: "Posted", value: job.postedDate.isEmpty ? "Recently" : job.postedDate)
        }
    }

    private var salaryValue: String {
        if let s = job.salaryText(currency: effectiveCurrency) { return s + (job.salaryPredicted ? " est." : "") }
        return "Not disclosed"
    }

    private var jobTypeValue: String {
        if let c = job.contractType, !c.isEmpty { return c.capitalized }
        return "Full-time"
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 76)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Highlights

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 10) {
                highlightRow(icon: "mappin.and.ellipse", text: locationHighlight)
                highlightRow(icon: "building.2.fill", text: "Hiring company: \(job.company.isEmpty ? "Undisclosed" : job.company)")
                highlightRow(icon: salaryHighlightIcon, text: salaryHighlight)
                highlightRow(icon: "bookmark.fill", text: "Bookmark this role to apply later, or tap Apply to view the full posting.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.surface.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.12), lineWidth: 1))
    }

    private var locationHighlight: String {
        job.location.isEmpty ? "Location shared on the job posting." : "Based in \(job.location)."
    }

    private var salaryHighlight: String {
        if let s = job.salaryText(currency: effectiveCurrency) {
            return job.salaryPredicted
                ? "Estimated pay around \(s) (Adzuna estimate)."
                : "Pay range: \(s)."
        }
        return "Salary not listed — check the full posting for details."
    }

    private var salaryHighlightIcon: String {
        job.salaryText(currency: effectiveCurrency) == nil ? "questionmark.circle.fill" : "dollarsign.circle.fill"
    }

    private func highlightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accentSoft)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this role")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(job.description)
                .font(.callout)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tap Apply to read the full posting.")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.surface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Toast

    private func toastView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
    }

    private func flashToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            heartButton
            bookmarkButton
            applyButton
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.accent.opacity(0.12)).frame(height: 1)
        }
    }

    private var heartButton: some View {
        Button {
            toggleFavorite()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                // White fill background when favorited, violet heart on top.
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isFavorite ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isFavorite ? Color.white : AppTheme.surface.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.accent.opacity(isFavorite ? 0.6 : 0.2), lineWidth: 1)
                )
                .scaleEffect(heartBounce ? 1.25 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var bookmarkButton: some View {
        Button {
            toggleBookmark()
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isBookmarked ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.accent.opacity(isBookmarked ? 0.5 : 0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var applyButton: some View {
        Button {
            Haptics.medium()
            showSafari = true
        } label: {
            HStack(spacing: 8) {
                Text("Apply")
                    .font(.headline)
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accentGradient)
            )
            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistence

    private func toggleFavorite() {
        Haptics.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { heartBounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { heartBounce = false }
        }

        if let record {
            record.isFavorite.toggle()
            flashToast(record.isFavorite ? "Added to favorites" : "Removed from favorites")
            cleanupIfEmpty(record)
        } else {
            context.insert(SavedJob(from: job, currency: currency, isFavorite: true))
            flashToast("Added to favorites")
        }
        try? context.save()
    }

    private func toggleBookmark() {
        Haptics.tap()
        if let record {
            record.isBookmarked.toggle()
            flashToast(record.isBookmarked ? "Saved to apply later" : "Removed from saved")
            cleanupIfEmpty(record)
        } else {
            context.insert(SavedJob(from: job, currency: currency, isBookmarked: true))
            flashToast("Saved to apply later")
        }
        try? context.save()
    }

    private func cleanupIfEmpty(_ record: SavedJob) {
        if !record.isFavorite && !record.isBookmarked {
            context.delete(record)
        }
    }
}

#Preview {
    NavigationStack {
        JobDetailView(
            job: Job(
                id: "preview-1", title: "iOS Engineer", company: "Acme Corp",
                location: "Remote", description: "Build delightful iOS apps.",
                url: "https://example.com", salaryMin: 8_000_000, salaryMax: 12_000_000,
                salaryPredicted: false, contractType: "permanent", category: "IT Jobs",
                created: "2026-08-01T00:00:00Z"
            )
        )
    }
    .modelContainer(for: SavedJob.self, inMemory: true)
    .preferredColorScheme(.dark)
}
