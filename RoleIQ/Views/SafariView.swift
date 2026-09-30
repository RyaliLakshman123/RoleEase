//
//  SafariView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 13/08/26.
//



import SwiftUI
import SafariServices

/// In-app Safari (SFSafariViewController) — opens a URL inside the app with a
/// Done button, instead of leaving RoleIQ for the Safari app.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(AppTheme.accent)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
