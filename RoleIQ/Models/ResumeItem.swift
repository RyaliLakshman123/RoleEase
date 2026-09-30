//
//  ResumeItem.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import SwiftData

@Model
final class ResumeItem {
    var id: UUID
    var fileName: String
    var extractedText: String
    var dateAdded: Date

    init(fileName: String, extractedText: String) {
        self.id = UUID()
        self.fileName = fileName
        self.extractedText = extractedText
        self.dateAdded = .now
    }
}
