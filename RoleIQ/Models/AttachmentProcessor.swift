//
//  AttachmentProcessor.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 30/08/26.
//


//
//  Turns picked attachments (PDFs, documents, photos, camera captures) into
//  plain TEXT on-device, so the chat backend and its wire format never change
//  and token cost stays near zero.
//
//  Strategy — always prefer text, never send raw files:
//    • PDFs / documents → PDFTextExtractor (existing). If a PDF is a scanned
//      image with no embedded text, we fall back to rasterizing + OCR.
//    • Photos / camera  → Vision OCR (on-device, free, zero tokens). A career
//      app's images are documents — resumes, JDs, offer letters — so reading
//      their text is exactly what's wanted, and true image vision (expensive,
//      needs a multimodal backend) isn't.
//
//  downscaleJPEG(...) is kept as a utility for the day you DO want to send a
//  real image to a vision model; it's not part of the default text-only flow.
//


import Foundation
import UIKit
import PDFKit
import Vision
import UniformTypeIdentifiers

enum AttachmentError: LocalizedError {
    case unreadableFile
    case noTextFound
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "Couldn't read that file."
        case .noTextFound:    return "No readable text found in that attachment."
        case .ocrFailed:      return "Couldn't read text from that image."
        }
    }
}

enum AttachmentProcessor {

    // MARK: - Public entry points

    /// Extract text from a document URL (PDF or plain text). Falls back to OCR
    /// for scanned PDFs that carry no embedded text.
    static func extractText(fromFile url: URL) async throws -> String {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)

        // Plain-text-ish files: read directly.
        if let type, type.conforms(to: .text) || type.conforms(to: .plainText) {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw AttachmentError.noTextFound
        }

        // PDFs: reuse the existing extractor, then OCR-fall-back if it's scanned.
        do {
            return try PDFTextExtractor.extractText(from: url)
        } catch PDFExtractionError.noTextFound {
            // Scanned PDF — rasterize each page and OCR it.
            return try await ocrText(fromScannedPDF: url)
        } catch {
            throw AttachmentError.unreadableFile
        }
    }

    /// Read the text out of a photo / camera capture via on-device OCR.
    static func extractText(fromImage image: UIImage) async throws -> String {
        try await ocrText(from: image)
    }

    // MARK: - OCR (Vision, on-device, free)

    private static func ocrText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw AttachmentError.ocrFailed }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(throwing: AttachmentError.ocrFailed)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if text.isEmpty {
                    continuation.resume(throwing: AttachmentError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: AttachmentError.ocrFailed) }
            }
        }
    }

    /// Rasterize each page of a scanned PDF and OCR them in order.
    private static func ocrText(fromScannedPDF url: URL) async throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { throw AttachmentError.unreadableFile }

        var pieces: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0   // enough resolution for reliable OCR
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            if let pageText = try? await ocrText(from: image) {
                pieces.append(pageText)
            }
        }

        let joined = pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw AttachmentError.noTextFound }
        return joined
    }

    // MARK: - Image downscale (kept for a future vision path)

    /// Downscale + JPEG-compress an image so that, IF you ever send a real image
    /// to a vision model, it costs far fewer tokens than a full-res photo.
    /// Not used by the default text-only flow.
    static func downscaleJPEG(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1.0
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
