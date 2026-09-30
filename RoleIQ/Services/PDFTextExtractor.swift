//
//  PDFTextExtractor.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import PDFKit

enum PDFExtractionError: LocalizedError {
    case couldNotOpenDocument
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .couldNotOpenDocument: return "Couldn't open that PDF."
        case .noTextFound: return "No readable text found in this PDF. It may be a scanned image."
        }
    }
}

enum PDFTextExtractor {
    static func extractText(from url: URL) throws -> String {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let document = PDFDocument(url: url) else {
            throw PDFExtractionError.couldNotOpenDocument
        }

        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            if let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PDFExtractionError.noTextFound
        }

        return trimmed
    }
}
