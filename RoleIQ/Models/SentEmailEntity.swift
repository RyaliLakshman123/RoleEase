//
//  SentEmailEntity.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 06/09/26.
//


//
//  SwiftData model for a recruiter email the user actually sent (mail composer
//  returned .sent). Stores the fields needed to list past sends and to re-open
//  a read-only copy of what was sent. Mirrors the ATSHistoryItem pattern.
//
//  NOTE: must be registered in RoleIQApp's .modelContainer array or saves
//  crash at runtime.
//

import Foundation
import SwiftData

@Model
final class SentEmailEntity {
    // Shown in the history list.
    var companyName: String
    var roleTitle: String
    var recipient: String
    var dateSent: Date

    // Full sent content, for re-opening a read-only copy.
    var subject: String
    var body: String

    init(
        companyName: String,
        roleTitle: String,
        recipient: String,
        subject: String,
        body: String,
        dateSent: Date = .now
    ) {
        self.companyName = companyName
        self.roleTitle = roleTitle
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.dateSent = dateSent
    }
}

extension SentEmailEntity {
    /// A friendly label for the company line, falling back when it's blank.
    var displayCompany: String {
        companyName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "a recruiter"
            : companyName
    }
}
