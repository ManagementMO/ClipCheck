//  DietaryProfile.swift
//  ClipCheck

import Foundation

// MARK: - Allergen

enum Allergen: String, CaseIterable, Identifiable {
    case peanuts, treeNuts, dairy, gluten, shellfish, eggs, fish, soy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .peanuts: return "Peanuts"
        case .treeNuts: return "Tree Nuts"
        case .dairy: return "Dairy"
        case .gluten: return "Gluten"
        case .shellfish: return "Shellfish"
        case .eggs: return "Eggs"
        case .fish: return "Fish"
        case .soy: return "Soy"
        }
    }

    var emoji: String {
        switch self {
        case .peanuts: return "🥜"
        case .treeNuts: return "🌰"
        case .dairy: return "🥛"
        case .gluten: return "🌾"
        case .shellfish: return "🦐"
        case .eggs: return "🥚"
        case .fish: return "🐟"
        case .soy: return "🫘"
        }
    }

    /// Parse from URL param value (e.g. "peanuts" or "tree-nuts")
    init?(urlValue: String) {
        let normalized = urlValue.lowercased().replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        switch normalized {
        case "peanuts", "peanut": self = .peanuts
        case "treenuts", "treenut": self = .treeNuts
        case "dairy", "milk", "lactose": self = .dairy
        case "gluten", "wheat": self = .gluten
        case "shellfish", "shrimp", "crab": self = .shellfish
        case "eggs", "egg": self = .eggs
        case "fish": self = .fish
        case "soy", "soya": self = .soy
        default: return nil
        }
    }
}

// MARK: - Dietary Preference

enum DietaryPreference: String, CaseIterable, Identifiable {
    case vegetarian, vegan, halal, kosher

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        }
    }

    var emoji: String {
        switch self {
        case .vegetarian: return "🌱"
        case .vegan: return "🌿"
        case .halal: return "☪️"
        case .kosher: return "✡️"
        }
    }

    init?(urlValue: String) {
        let normalized = urlValue.lowercased()
        switch normalized {
        case "vegetarian", "veg": self = .vegetarian
        case "vegan": self = .vegan
        case "halal": self = .halal
        case "kosher": self = .kosher
        default: return nil
        }
    }
}

// MARK: - Dietary Profile

struct DietaryProfile {
    var allergens: Set<Allergen> = []
    var preferences: Set<DietaryPreference> = []

    var isEmpty: Bool { allergens.isEmpty && preferences.isEmpty }

    /// Human-readable summary, e.g. "Dairy-free, Gluten-free, Halal"
    var summary: String {
        var parts: [String] = []
        for a in Allergen.allCases where allergens.contains(a) {
            parts.append("\(a.label)-free")
        }
        for p in DietaryPreference.allCases where preferences.contains(p) {
            parts.append(p.label)
        }
        return parts.isEmpty ? "No restrictions" : parts.joined(separator: ", ")
    }

    /// Prompt fragment for Gemini
    var promptFragment: String {
        guard !isEmpty else { return "" }
        var parts: [String] = []
        if !allergens.isEmpty {
            parts.append("Allergies: \(allergens.map(\.label).joined(separator: ", "))")
        }
        if !preferences.isEmpty {
            parts.append("Diet: \(preferences.map(\.label).joined(separator: ", "))")
        }
        return parts.joined(separator: ". ") + "."
    }

    /// Parse from URL query params: ?allergens=peanuts,dairy&diet=halal
    static func fromQuery(_ params: [String: String]) -> DietaryProfile? {
        var profile = DietaryProfile()
        if let allergenStr = params["allergens"] {
            for raw in allergenStr.split(separator: ",") {
                if let a = Allergen(urlValue: String(raw)) {
                    profile.allergens.insert(a)
                }
            }
        }
        if let dietStr = params["diet"] {
            for raw in dietStr.split(separator: ",") {
                if let p = DietaryPreference(urlValue: String(raw)) {
                    profile.preferences.insert(p)
                }
            }
        }
        return profile.isEmpty ? nil : profile
    }
}
