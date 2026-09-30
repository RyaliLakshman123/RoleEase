//
//  ResumeUploadViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import SwiftData

@Observable
final class ResumeUploadViewModel {
    var extractedText: String = ""
    var resumePDFData: Data?   // raw PDF bytes for attaching to emails
    var errorMessage: String?
    var isProcessing = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func handlePickedPDF(url: URL) {
        errorMessage = nil
        isProcessing = true

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)          // raw PDF bytes
                let text = try PDFTextExtractor.extractText(from: url)
                await self.finishExtraction(text: text, data: data, fileName: url.lastPathComponent)
            } catch {
                await self.finishWithError(error)
            }
        }
    }

    @MainActor
    private func finishExtraction(text: String, data: Data, fileName: String) {
        extractedText = text
        resumePDFData = data
        let item = ResumeItem(fileName: fileName, extractedText: text)
        modelContext.insert(item)
        isProcessing = false
    }

    @MainActor
    private func finishWithError(_ error: Error) {
        errorMessage = error.localizedDescription
        isProcessing = false
    }
}
