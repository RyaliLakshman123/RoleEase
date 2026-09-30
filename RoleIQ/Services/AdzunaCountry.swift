//
//  AdzunaCountry.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 13/08/26.
//



import Foundation

/// A country Adzuna has a job index for. `code` is the lowercase slug used in
/// the API path (e.g. "us" → /jobs/us/search/...). `currencySymbol` is used to
/// format salaries in local currency.
struct AdzunaCountry: Identifiable, Hashable {
    let code: String          // "in", "us", "gb", ...
    let name: String          // "India", "United States", ...
    let flag: String          // emoji flag
    let currencySymbol: String // "₹", "$", "£", ...
    let defaultCity: String   // sensible default location for the search box

    var id: String { code }

    /// Every country Adzuna currently supports.
    static let all: [AdzunaCountry] = [
        AdzunaCountry(code: "in", name: "India",          flag: "🇮🇳", currencySymbol: "₹",  defaultCity: "Chennai"),
        AdzunaCountry(code: "us", name: "United States",  flag: "🇺🇸", currencySymbol: "$",  defaultCity: "New York"),
        AdzunaCountry(code: "gb", name: "United Kingdom", flag: "🇬🇧", currencySymbol: "£",  defaultCity: "London"),
        AdzunaCountry(code: "ca", name: "Canada",         flag: "🇨🇦", currencySymbol: "$",  defaultCity: "Toronto"),
        AdzunaCountry(code: "au", name: "Australia",      flag: "🇦🇺", currencySymbol: "$",  defaultCity: "Sydney"),
        AdzunaCountry(code: "de", name: "Germany",        flag: "🇩🇪", currencySymbol: "€",  defaultCity: "Berlin"),
        AdzunaCountry(code: "fr", name: "France",         flag: "🇫🇷", currencySymbol: "€",  defaultCity: "Paris"),
        AdzunaCountry(code: "es", name: "Spain",          flag: "🇪🇸", currencySymbol: "€",  defaultCity: "Madrid"),
        AdzunaCountry(code: "it", name: "Italy",          flag: "🇮🇹", currencySymbol: "€",  defaultCity: "Rome"),
        AdzunaCountry(code: "nl", name: "Netherlands",    flag: "🇳🇱", currencySymbol: "€",  defaultCity: "Amsterdam"),
        AdzunaCountry(code: "at", name: "Austria",        flag: "🇦🇹", currencySymbol: "€",  defaultCity: "Vienna"),
        AdzunaCountry(code: "be", name: "Belgium",        flag: "🇧🇪", currencySymbol: "€",  defaultCity: "Brussels"),
        AdzunaCountry(code: "br", name: "Brazil",         flag: "🇧🇷", currencySymbol: "R$", defaultCity: "São Paulo"),
        AdzunaCountry(code: "mx", name: "Mexico",         flag: "🇲🇽", currencySymbol: "$",  defaultCity: "Mexico City"),
        AdzunaCountry(code: "nz", name: "New Zealand",    flag: "🇳🇿", currencySymbol: "$",  defaultCity: "Auckland"),
        AdzunaCountry(code: "pl", name: "Poland",         flag: "🇵🇱", currencySymbol: "zł", defaultCity: "Warsaw"),
        AdzunaCountry(code: "sg", name: "Singapore",      flag: "🇸🇬", currencySymbol: "$",  defaultCity: "Singapore"),
        AdzunaCountry(code: "za", name: "South Africa",   flag: "🇿🇦", currencySymbol: "R",  defaultCity: "Johannesburg")
    ]

    static let fallback = all[0] // India

    static func with(code: String) -> AdzunaCountry {
        all.first { $0.code == code.lowercased() } ?? fallback
    }

    /// Best-guess country from the device region, falling back to India if the
    /// user's region has no Adzuna index (e.g. Japan).
    static func detected() -> AdzunaCountry {
        let region = Locale.current.region?.identifier.lowercased() ?? "in"
        return all.first { $0.code == region } ?? fallback
    }
}
