//
//  AuthViewModel.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 01/08/26.
//

import Foundation
import AuthenticationServices

@Observable
final class AuthViewModel {

    var isSignedIn: Bool
    var isGuest: Bool
    var userName: String?
    var errorMessage: String?
    var avatarColorHex: String?

    private let userIDKey = "RoleIQ.appleUserID"
    private let userNameKey = "RoleIQ.userName"
    private let avatarColorKey = "RoleIQ.avatarColorHex"
    private let guestModeKey = "RoleIQ.guestMode"

    init() {
        self.isSignedIn = UserDefaults.standard.string(forKey: userIDKey) != nil
        self.isGuest = UserDefaults.standard.bool(forKey: guestModeKey)
        self.userName = UserDefaults.standard.string(forKey: userNameKey)
        self.avatarColorHex = UserDefaults.standard.string(forKey: avatarColorKey)
    }

    var canEnterApp: Bool {
        isSignedIn || isGuest
    }

    var effectiveAvatarHex: String {
        if let avatarColorHex, !avatarColorHex.isEmpty {
            return avatarColorHex
        }

        return AvatarGenerator.derivedHex(for: userName ?? "")
    }

    // MARK: - Sign in with Apple

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {

        switch result {

        case .success(let authorization):

            guard let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type."
                return
            }

            let userID = credential.user

            UserDefaults.standard.set(userID, forKey: userIDKey)

            // User is no longer in guest mode.
            UserDefaults.standard.removeObject(forKey: guestModeKey)
            isGuest = false

            if let fullName = credential.fullName {

                let name = [
                    fullName.givenName,
                    fullName.familyName
                ]
                .compactMap { $0 }
                .joined(separator: " ")

                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: userNameKey)
                    userName = name
                }
            }

            errorMessage = nil
            isSignedIn = true

        case .failure(let error):

            let nsError = error as NSError

            let silentCodes: [Int] = [
                ASAuthorizationError.canceled.rawValue,
                ASAuthorizationError.unknown.rawValue
            ]

            if !silentCodes.contains(nsError.code) {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = nil
            }
        }
    }

    // MARK: - Guest Mode

    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: guestModeKey)

        isGuest = true
        errorMessage = nil
    }

    // MARK: - Sign Out

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: guestModeKey)

        isSignedIn = false
        isGuest = false
    }

    // MARK: - Delete Account

    func deleteAccount() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: avatarColorKey)
        UserDefaults.standard.removeObject(forKey: guestModeKey)

        avatarColorHex = nil
        userName = nil
        isSignedIn = false
        isGuest = false
        errorMessage = nil
    }

    func updateName(_ newName: String) {

        let trimmed = newName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        UserDefaults.standard.set(trimmed, forKey: userNameKey)
        userName = trimmed
    }

    func updateAvatarColor(_ hex: String?) {

        if let hex, !hex.isEmpty {
            UserDefaults.standard.set(hex, forKey: avatarColorKey)
            avatarColorHex = hex
        } else {
            UserDefaults.standard.removeObject(forKey: avatarColorKey)
            avatarColorHex = nil
        }
    }
}
