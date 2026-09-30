//
//  AppTheme.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .init(charactersIn: "#")))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

enum AppTheme {
    static let background = Color(hex: "0B0B12")
    static let surface = Color(hex: "17151F")
    static let surfaceLight = Color(hex: "221F2E")

    static let accent = Color(hex: "8B5CF6")
    static let accentDeep = Color(hex: "5B21B6")
    static let accentSoft = Color(hex: "A78BFA")

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "6B7280")

    static let danger = Color(hex: "F87171")

    static let gold = Color(red: 0.96, green: 0.78, blue: 0.25)      // ~#F5C740
    static let goldSoft = Color(red: 1.0, green: 0.89, blue: 0.55)   // lighter highlight
    
    static let backgroundGradient = LinearGradient(
        colors: [background, accentDeep.opacity(0.35), background],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let screenGradient = LinearGradient(
            gradient: Gradient(stops: [
                .init(color: background, location: 0.0),
                .init(color: background, location: 0.55),
                .init(color: Color(hex: "290F42"), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
    )
    

    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .leading,
        endPoint: .trailing
    )
}
