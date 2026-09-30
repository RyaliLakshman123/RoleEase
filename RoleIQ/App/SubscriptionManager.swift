//
//  SubscriptionManager.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 08/09/26.
//

import Foundation
import RevenueCat
import Combine

@MainActor
final class SubscriptionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isProUser = false
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Constants

    private let entitlementID = "RoleIQ Pro"

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Configure RevenueCat

    func configure() {
        Purchases.logLevel = .debug

        Purchases.configure(
            withAPIKey: "your_public_sdk_key"
        )

        Purchases.shared.delegate = self
    }

    // MARK: - Load Subscription Status

    func loadCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateSubscriptionStatus(with: customerInfo)
        } catch {
            print("❌ Failed to fetch customer info: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Offerings

    func loadOfferings() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current

            if currentOffering == nil {
                print("⚠️ No current offering available")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load offerings: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            updateSubscriptionStatus(with: result.customerInfo)

            return isProUser

        } catch {
            if let errorCode = error as? RevenueCat.ErrorCode,
               errorCode == .purchaseCancelledError {
                return false
            }

            errorMessage = error.localizedDescription
            print("❌ Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateSubscriptionStatus(with: customerInfo)

            return isProUser

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Restore failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Helpers

    private func updateSubscriptionStatus(with customerInfo: CustomerInfo) {
        isProUser =
            customerInfo.entitlements.active[entitlementID] != nil

        print("🔐 RoleIQ Pro status: \(isProUser)")
    }
}


// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {

    nonisolated func purchases(
        _ purchases: Purchases,
        receivedUpdated customerInfo: CustomerInfo
    ) {
        Task { @MainActor in
            self.updateSubscriptionStatus(with: customerInfo)
        }
    }
}
