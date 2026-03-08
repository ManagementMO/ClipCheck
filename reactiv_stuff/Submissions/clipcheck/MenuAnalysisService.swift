//  MenuAnalysisService.swift
//  ClipCheck

import Foundation

// MARK: - Models

struct MenuRecommendation {
    let dishName: String
    let reason: String
}

struct MenuAvoidance {
    let dishName: String
    let reason: String
}

struct MenuAnalysisResult {
    let recommended: [MenuRecommendation]
    let avoid: [MenuAvoidance]
}

// MARK: - Service

@Observable
final class MenuAnalysisService {
    private(set) var result: MenuAnalysisResult?
    private(set) var isLoading = false
    private(set) var error: String?

    private static var apiKey: String { Secrets.geminiAPIKey }
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"

    func analyze(restaurant: RestaurantData, dietary: DietaryProfile) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        result = nil

        Task {
            do {
                let analysis = try await fetchAnalysis(restaurant: restaurant, dietary: dietary)
                await MainActor.run {
                    self.result = analysis
                    self.isLoading = false
                }
            } catch {
                print("[MenuAnalysis] ERROR: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.result = Self.fallback(restaurant: restaurant, dietary: dietary)
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Network

    private func fetchAnalysis(restaurant: RestaurantData, dietary: DietaryProfile) async throws -> MenuAnalysisResult {
        let prompt = Self.buildPrompt(restaurant: restaurant, dietary: dietary)

        var urlComponents = URLComponents(string: Self.endpoint)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: Self.apiKey)]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 600
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[MenuAnalysis] HTTP \(code)")
            throw MenuAnalysisError.httpError(code)
        }

        return try Self.parseResponse(data)
    }

    // MARK: - Prompt

    private static func buildPrompt(restaurant: RestaurantData, dietary: DietaryProfile) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let mealTime = hour < 11 ? "breakfast" : hour < 16 ? "lunch" : "dinner"

        var lines: [String] = []
        lines.append("You are a menu advisor for a diner at \(restaurant.name), a \(restaurant.type) restaurant. It is \(mealTime) time.")
        lines.append("")

        // Violations context
        let recentViolations = restaurant.inspections.first?.infractions ?? []
        if recentViolations.isEmpty {
            lines.append("This restaurant has a clean inspection record with no violations.")
        } else {
            lines.append("Recent inspection violations:")
            for v in recentViolations.prefix(5) {
                lines.append("- [\(v.severity)] \(v.detail)")
            }
        }

        // Dietary context
        if !dietary.isEmpty {
            lines.append("")
            lines.append("Customer dietary restrictions: \(dietary.promptFragment)")
            lines.append("All recommendations MUST be safe for these restrictions. All items to avoid must consider these restrictions.")
        }

        lines.append("")
        lines.append("Based on the restaurant type, likely menu, inspection violations, and dietary needs, respond in EXACTLY this format. Plain text only, no markdown:")
        lines.append("")
        lines.append("RECOMMEND1: [dish name] | [one sentence reason referencing safety or dietary fit]")
        lines.append("RECOMMEND2: [dish name] | [one sentence reason]")
        lines.append("RECOMMEND3: [dish name] | [one sentence reason]")
        lines.append("AVOID1: [dish name] | [one sentence reason referencing a specific violation or allergen risk]")
        lines.append("AVOID2: [dish name] | [one sentence reason]")
        lines.append("")
        lines.append("Be specific to this restaurant type. A Chinese restaurant should have Chinese dishes, a pizza place should have pizza items, etc. Reference actual violations when explaining what to avoid.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Parse

    private static func parseResponse(_ data: Data) throws -> MenuAnalysisResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw MenuAnalysisError.parseError
        }

        // Gemini 2.5 Flash may include "thought" parts — skip them
        let textParts = parts.filter { ($0["thought"] as? Bool) != true }
        guard let text = textParts.last?["text"] as? String ?? parts.last?["text"] as? String else {
            throw MenuAnalysisError.parseError
        }

        let cleaned = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        print("[MenuAnalysis] Raw:\n\(cleaned)")

        var recommended: [MenuRecommendation] = []
        var avoid: [MenuAvoidance] = []

        for line in cleaned.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("RECOMMEND") {
                // Strip label like "RECOMMEND1: "
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    let content = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    let parts = content.split(separator: "|", maxSplits: 1)
                    if let name = parts.first {
                        let reason = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "Safe choice based on inspection data"
                        recommended.append(MenuRecommendation(dishName: String(name).trimmingCharacters(in: .whitespaces), reason: reason))
                    }
                }
            } else if trimmed.uppercased().hasPrefix("AVOID") {
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    let content = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    let parts = content.split(separator: "|", maxSplits: 1)
                    if let name = parts.first {
                        let reason = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "May carry risk based on recent violations"
                        avoid.append(MenuAvoidance(dishName: String(name).trimmingCharacters(in: .whitespaces), reason: reason))
                    }
                }
            }
        }

        // Ensure we have at least something
        if recommended.isEmpty {
            return fallback(text: text)
        }

        return MenuAnalysisResult(recommended: Array(recommended.prefix(3)), avoid: Array(avoid.prefix(2)))
    }

    // MARK: - Fallback

    private static func fallback(text: String = "") -> MenuAnalysisResult {
        MenuAnalysisResult(
            recommended: [
                MenuRecommendation(dishName: "Freshly cooked entrée", reason: "Cooked-to-order items minimize food safety risk"),
                MenuRecommendation(dishName: "Hot soup or broth", reason: "High cooking temperatures ensure safety"),
                MenuRecommendation(dishName: "Grilled or baked dish", reason: "Thorough cooking reduces bacterial risk"),
            ],
            avoid: [
                MenuAvoidance(dishName: "Raw or cold-prepared items", reason: "Higher risk if temperature control was cited"),
                MenuAvoidance(dishName: "Pre-made salads or buffet items", reason: "Longer exposure time increases contamination risk"),
            ]
        )
    }

    static func fallback(restaurant: RestaurantData, dietary: DietaryProfile) -> MenuAnalysisResult {
        let violations = restaurant.inspections.first?.infractions ?? []
        let details = violations.map { $0.detail.lowercased() }
        let hasTemp = details.contains { $0.contains("temperature") || $0.contains("cold") || $0.contains("refrigerat") }
        let hasSanitation = details.contains { $0.contains("sanit") || $0.contains("clean") || $0.contains("wash") }

        var recs: [MenuRecommendation] = []
        var avoids: [MenuAvoidance] = []

        // Recommendations based on restaurant type
        let type = restaurant.type.lowercased()
        if type.contains("chinese") || type.contains("asian") {
            recs.append(MenuRecommendation(dishName: "Stir-fried noodles or rice", reason: "High-heat wok cooking ensures food safety"))
            recs.append(MenuRecommendation(dishName: "Hot & sour soup", reason: "Boiled preparation eliminates bacterial risk"))
            recs.append(MenuRecommendation(dishName: "Steamed dumplings", reason: "Steam cooking is one of the safest preparation methods"))
        } else if type.contains("pizza") || type.contains("italian") {
            recs.append(MenuRecommendation(dishName: "Wood-fired pizza", reason: "Oven temperatures exceed 400°F — very safe"))
            recs.append(MenuRecommendation(dishName: "Baked pasta dish", reason: "Thorough oven baking eliminates pathogens"))
            recs.append(MenuRecommendation(dishName: "Minestrone soup", reason: "Boiled soup is a reliably safe choice"))
        } else if type.contains("indian") || type.contains("curry") {
            recs.append(MenuRecommendation(dishName: "Tandoori chicken", reason: "Tandoor oven reaches extreme temperatures"))
            recs.append(MenuRecommendation(dishName: "Dal or lentil curry", reason: "Slow-cooked legumes are thoroughly heated"))
            recs.append(MenuRecommendation(dishName: "Fresh naan bread", reason: "Baked to order in the tandoor"))
        } else {
            recs.append(MenuRecommendation(dishName: "Grilled entrée", reason: "High-heat grilling ensures thorough cooking"))
            recs.append(MenuRecommendation(dishName: "Hot soup", reason: "Boiled preparation is reliably safe"))
            recs.append(MenuRecommendation(dishName: "Baked or roasted dish", reason: "Oven cooking eliminates bacterial risk"))
        }

        // Avoids based on violations
        if hasTemp {
            avoids.append(MenuAvoidance(dishName: "Cold salads or sushi", reason: "Temperature control violations were cited — cold items carry higher risk"))
        } else {
            avoids.append(MenuAvoidance(dishName: "Raw or undercooked items", reason: "Minimize exposure to uncooked ingredients"))
        }
        if hasSanitation {
            avoids.append(MenuAvoidance(dishName: "Fresh-cut fruit or garnishes", reason: "Sanitation issues were flagged — avoid items requiring manual handling"))
        } else {
            avoids.append(MenuAvoidance(dishName: "Buffet or self-serve items", reason: "Extended exposure time increases contamination risk"))
        }

        // Add dietary note to first recommendation
        if !dietary.isEmpty {
            let note = " Confirm with server that this is \(dietary.summary.lowercased())-compatible."
            recs[0] = MenuRecommendation(dishName: recs[0].dishName, reason: recs[0].reason + note)
        }

        return MenuAnalysisResult(recommended: recs, avoid: avoids)
    }
}

enum MenuAnalysisError: LocalizedError {
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Menu analysis failed (HTTP \(code))"
        case .parseError: return "Could not parse menu analysis"
        }
    }
}
