//
//  AppRouter.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//


import SwiftUI

enum AppScreen {
    case onboarding
    case signIn
    case nameEntry
    case home
}

@Observable
final class AppRouter {

    var currentScreen: AppScreen = .onboarding

    func go(to screen: AppScreen) {

        withAnimation(.easeInOut(duration: 0.25)) {

            currentScreen = screen
        }
    }
}
