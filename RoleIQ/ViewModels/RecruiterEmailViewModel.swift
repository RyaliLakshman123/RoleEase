//
//  RecruiterEmailViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 12/08/26.
//



import SwiftUI
import Combine

enum EmailTone: String, CaseIterable, Identifiable {
    case professional = "Professional"
    case warm = "Warm"
    case confident = "Confident"

    var id: String { rawValue }
    var apiValue: String { rawValue.lowercased() }
}

@MainActor
class RecruiterEmailViewModel: ObservableObject {
    @Published var recruiterEmail = ""
    @Published var companyName = ""
    @Published var roleTitle = ""
    @Published var jobDescription = ""
    @Published var userName = ""
    @Published var tone: EmailTone = .professional

    // Editable draft, populated once generated.
    @Published var hasDraft = false
    @Published var draftSubject = ""
    @Published var draftBody = ""

    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var showConfetti = false
    @Published var showToast = false
    @Published var showCopyToast = false
    @Published var resumeSummary = ""

    var wordCount: Int {
        draftBody.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
    }

    /// Assembles an outgoing draft struct from the editable fields.
    var currentDraft: RecruiterEmailDraft {
        RecruiterEmailDraft(subject: draftSubject, body: draftBody)
    }

    func generateDraft() async {
        guard !recruiterEmail.isEmpty, !roleTitle.isEmpty else {
            errorMessage = "Recruiter email and role title are required."
            Haptics.error()
            return
        }
        isGenerating = true
        errorMessage = nil

        do {
            let draft = try await draftWithRetry()
            draftSubject = draft.subject
            draftBody = draft.body
            hasDraft = true
            Haptics.success()
            triggerSuccessFeedback()
        } catch BackendService.BackendError.rateLimited {
            errorMessage = "AI is a bit busy — try again in a minute."
            Haptics.error()
        } catch {
            print("EMAIL DRAFT ERROR:", error)
            errorMessage = "Couldn't generate draft. Try again."
            Haptics.error()
        }
        isGenerating = false
    }

    private func draftWithRetry() async throws -> RecruiterEmailDraft {
        do {
            return try await callBackend()
        } catch let error as URLError where error.code == .networkConnectionLost || error.code == .timedOut {
            // Likely a Render cold start — wake-up request dropped. Retry once.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return try await callBackend()
        }
    }

    private func callBackend() async throws -> RecruiterEmailDraft {
        try await BackendService.shared.generateEmailDraft(
            recruiterEmail: recruiterEmail,
            companyName: companyName,
            roleTitle: roleTitle,
            jobDescription: jobDescription,
            resumeSummary: resumeSummary,
            userName: userName.isEmpty ? "Applicant" : userName,
            tone: tone.apiValue
        )
    }

    func startNewDraft() {
        recruiterEmail = ""
        companyName = ""
        roleTitle = ""
        jobDescription = ""
        tone = .professional
        hasDraft = false
        draftSubject = ""
        draftBody = ""
        errorMessage = nil
        // keep userName — same person drafting again
    }
    
    func flashCopyToast() {
        showCopyToast = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showCopyToast = false
        }
    }
    
    private func triggerSuccessFeedback() {
        showConfetti = true
        showToast = true

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            showToast = false
            showConfetti = false
        }
    }
}
