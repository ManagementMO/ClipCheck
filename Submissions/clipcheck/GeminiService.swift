//  GeminiService.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import Foundation

@Observable
final class GeminiService {
    private(set) var result: AdvisorResult?
    private(set) var isLoading = false
    private(set) var error: String?

    private static var apiKey: String { Secrets.geminiAPIKey }
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"

    struct AdvisorResult {
        let summary: String
        let concerns: String
        let recommendations: String
        let riskLevel: String
        let weatherTip: String
        let timeTip: String
        let allergenWarning: String
        let rawResponse: String
    }

    func analyze(_ restaurant: RestaurantData, dietary: DietaryProfile = DietaryProfile(), personalization: PersonalizationContext? = nil) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        result = nil

        let ctx = personalization ?? PersonalizationContext(dietary: dietary)

        Task {
            do {
                let advisor = try await fetchAdvisorResult(for: restaurant, context: ctx)
                await MainActor.run {
                    self.result = advisor
                    self.isLoading = false
                }
            } catch {
                print("[GeminiService] ERROR: \(error)")
                print("[GeminiService] Localized: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.result = Self.fallback(for: restaurant, context: ctx)
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Network

    private func fetchAdvisorResult(for restaurant: RestaurantData, context: PersonalizationContext) async throws -> AdvisorResult {
        let prompt = Self.buildPrompt(for: restaurant, context: context)

        var urlComponents = URLComponents(string: Self.endpoint)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: Self.apiKey)]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1200
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-UTF8 data, \(data.count) bytes>"
            print("[GeminiService] HTTP \(statusCode) — request failed")
            print("[GeminiService] Response body: \(bodyString)")
            throw GeminiError.httpError(statusCode)
        }

        return try Self.parseResponse(data)
    }

    // MARK: - Prompt

    private static func buildPrompt(for restaurant: RestaurantData, context: PersonalizationContext) -> String {
        var lines: [String] = []
        lines.append("You are a food safety advisor helping diners make informed decisions. A customer just scanned a QR code at \(restaurant.name) and wants to know if it's safe to eat here right now.")
        lines.append("")
        lines.append("Here is the official public health inspection data:")
        lines.append("")
        lines.append("Restaurant: \(restaurant.name)")
        lines.append("Address: \(restaurant.address)")
        lines.append("Cuisine: \(restaurant.type)")
        lines.append("Computed Trust Score: \(restaurant.trustScore)/100 (\(restaurant.trustLevel.label))")

        // Personalization context: weather, time, dietary
        lines.append("")
        lines.append(context.promptFragment)

        if !context.dietary.isEmpty {
            lines.append("")
            lines.append("IMPORTANT — Customer dietary profile: \(context.dietary.promptFragment)")
            lines.append("All recommendations MUST account for these restrictions. Flag any menu categories that may conflict with these needs.")
        }

        lines.append("")

        if restaurant.inspections.isEmpty {
            lines.append("No inspection records found.")
        } else {
            for (i, inspection) in restaurant.inspections.prefix(3).enumerated() {
                let recency = i == 0 ? " (most recent)" : ""
                lines.append("--- Inspection \(i + 1)\(recency): \(inspection.date) — \(inspection.status) ---")
                if inspection.infractions.isEmpty {
                    lines.append("  No violations found.")
                } else {
                    lines.append("  \(inspection.infractions.count) violation(s):")
                    for infraction in inspection.infractions {
                        lines.append("  [\(infraction.severity)] \(infraction.detail)")
                        if !infraction.action.isEmpty {
                            lines.append("    Action taken: \(infraction.action)")
                        }
                    }
                }
                lines.append("")
            }
        }

        lines.append("Write a safety briefing for the customer. Be specific — reference actual violations, dates, and patterns from the data above. Do NOT be generic. The customer is standing in the restaurant right now and needs actionable advice.")
        lines.append("Factor in the current weather and time of day when making your recommendations — e.g., cold weather favors hot cooked dishes (safer); late afternoon means food may have been sitting longer.")
        lines.append("")
        lines.append("Use EXACTLY this format with plain text only (no markdown, no asterisks, no bullet points):")
        lines.append("")
        lines.append("SUMMARY: Two to three sentences. Mention the restaurant by name, its most recent inspection result and date, and whether the trend is improving or declining. Be specific about what was found.")
        lines.append("")
        lines.append("CONCERNS: One to two sentences about the most worrying violation patterns. Reference specific violations from the data (e.g., \"cold food stored at unsafe temperatures\" not just \"food safety issues\"). If the record is clean, write \"None — this restaurant has a clean inspection record.\"")
        lines.append("")
        lines.append("RECOMMENDATIONS: Two to three specific, practical tips. Tell the customer exactly what to order or avoid based on the violations found AND the current weather/time context. For example: \"It's cold outside so you'll want hot food anyway — stick to grilled items since refrigeration was cited.\" If the record is clean, explain what makes this a confident choice.")
        lines.append("")
        lines.append("WEATHER_TIP: One sentence about how today's weather affects food safety choices at this specific restaurant. Reference the temperature and conditions.")
        lines.append("")
        lines.append("TIME_TIP: One sentence about how the current time of day affects food freshness at this restaurant.")
        lines.append("")
        lines.append("ALLERGEN_WARNING: If the diner specified allergens or dietary restrictions, give specific advice about cross-contamination risk based on the violations found. If no allergens specified, write \"No specific allergen concerns.\"")
        lines.append("")
        lines.append("RISK: Exactly one word: LOW, MODERATE, or HIGH")

        return lines.joined(separator: "\n")
    }

    // MARK: - Parse

    private static func parseResponse(_ data: Data) throws -> AdvisorResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            let rawString = String(data: data, encoding: .utf8) ?? "<non-UTF8 data, \(data.count) bytes>"
            print("[GeminiService] Parse failed. Raw response: \(rawString)")
            throw GeminiError.parseError
        }

        // Gemini 2.5 Flash may return "thought" parts before the actual text.
        // Find the last non-thought text part (the actual response).
        let textParts = parts.filter { ($0["thought"] as? Bool) != true }
        guard let text = textParts.last?["text"] as? String ?? parts.last?["text"] as? String else {
            print("[GeminiService] No text part found in \(parts.count) parts")
            throw GeminiError.parseError
        }

        return parseStructured(text)
    }

    private static func parseStructured(_ text: String) -> AdvisorResult {
        print("[GeminiService] Raw response:\n\(text)")

        // Strip markdown bold/italic markers (**, *, __)
        let cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")

        // Normalize alternate label "TIPS:" to "RECOMMENDATIONS:" so the parser finds it
        let normalized = cleaned.replacingOccurrences(
            of: "TIPS:",
            with: "RECOMMENDATIONS:",
            options: .caseInsensitive
        )

        // Known field labels in order of appearance
        let labels = ["SUMMARY:", "CONCERNS:", "RECOMMENDATIONS:", "WEATHER_TIP:", "TIME_TIP:", "ALLERGEN_WARNING:", "RISK:"]

        /// Extracts the content for a given label by capturing everything from that label
        /// until the next known label (or end of text). Handles multi-line values,
        /// case-insensitive label matching, and markdown-stripped text.
        func extract(_ label: String, from text: String) -> String {
            let upper = text.uppercased()
            let labelUpper = label.uppercased()

            // Find where this label starts (case-insensitive)
            guard let labelRange = upper.range(of: labelUpper) else {
                print("[GeminiService] WARNING: Label '\(label)' not found in response")
                return "N/A"
            }

            // Content starts right after the label
            let contentStart = labelRange.upperBound

            // Find where the next known label begins (the earliest one after our label)
            var contentEnd = text.endIndex
            for other in labels where other.uppercased() != labelUpper {
                if let otherRange = upper.range(of: other.uppercased(), range: contentStart..<text.endIndex) {
                    if otherRange.lowerBound < contentEnd {
                        contentEnd = otherRange.lowerBound
                    }
                }
            }

            let value = String(text[contentStart..<contentEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return value.isEmpty ? "N/A" : value
        }

        let summary = extract("SUMMARY:", from: normalized)
        let concerns = extract("CONCERNS:", from: normalized)
        let recommendations = extract("RECOMMENDATIONS:", from: normalized)
        let weatherTip = extract("WEATHER_TIP:", from: normalized)
        let timeTip = extract("TIME_TIP:", from: normalized)
        let allergenWarning = extract("ALLERGEN_WARNING:", from: normalized)
        var risk = extract("RISK:", from: normalized).uppercased()

        // Log each parsed field
        print("[GeminiService] Parsed SUMMARY: \"\(summary)\"")
        print("[GeminiService] Parsed CONCERNS: \"\(concerns)\"")
        print("[GeminiService] Parsed RECOMMENDATIONS: \"\(recommendations)\"")
        print("[GeminiService] Parsed WEATHER_TIP: \"\(weatherTip)\"")
        print("[GeminiService] Parsed TIME_TIP: \"\(timeTip)\"")
        print("[GeminiService] Parsed ALLERGEN_WARNING: \"\(allergenWarning)\"")
        print("[GeminiService] Parsed RISK: \"\(risk)\"")

        // Warn about N/A fields
        if summary == "N/A" { print("[GeminiService] WARNING: Field SUMMARY extracted as N/A from response") }
        if concerns == "N/A" { print("[GeminiService] WARNING: Field CONCERNS extracted as N/A from response") }
        if recommendations == "N/A" { print("[GeminiService] WARNING: Field RECOMMENDATIONS extracted as N/A from response") }
        if risk == "N/A" { print("[GeminiService] WARNING: Field RISK extracted as N/A from response") }

        // Normalize risk level
        if !["LOW", "MODERATE", "HIGH"].contains(risk) {
            print("[GeminiService] WARNING: Risk level '\(risk)' not recognized, defaulting to MODERATE")
            risk = "MODERATE"
        }

        return AdvisorResult(
            summary: summary,
            concerns: concerns,
            recommendations: recommendations,
            riskLevel: risk,
            weatherTip: weatherTip,
            timeTip: timeTip,
            allergenWarning: allergenWarning,
            rawResponse: text
        )
    }

    // MARK: - Fallback

    static func fallback(for restaurant: RestaurantData, context: PersonalizationContext) -> AdvisorResult {
        let dietary = context.dietary
        let name = restaurant.name
        let score = restaurant.trustScore
        let inspections = restaurant.inspections
        let latest = inspections.first

        // Count violations across all inspections
        let allInfractions = inspections.flatMap { $0.infractions }
        let crucialCount = allInfractions.filter { $0.parsedSeverity == .crucial }.count
        let significantCount = allInfractions.filter { $0.parsedSeverity == .significant }.count
        let totalViolations = allInfractions.count

        let latestDateStr = latest?.date ?? "unknown date"
        let latestStatus = latest?.parsedStatus.label ?? "unknown"
        let latestViolationCount = latest?.infractions.count ?? 0

        // Gather specific violation details
        let recentCrucial = latest?.infractions.filter { $0.parsedSeverity == .crucial } ?? []
        let recentSignificant = latest?.infractions.filter { $0.parsedSeverity == .significant } ?? []
        let topViolation = (recentCrucial.first ?? recentSignificant.first)?.detail

        // Detect violation categories
        let allDetails = allInfractions.map { $0.detail.lowercased() }
        let hasTemperatureIssues = allDetails.contains { $0.contains("temperature") || $0.contains("cold") || $0.contains("hot holding") || $0.contains("refrigerat") }
        let hasSanitationIssues = allDetails.contains { $0.contains("sanit") || $0.contains("clean") || $0.contains("wash") }
        let hasPestIssues = allDetails.contains { $0.contains("pest") || $0.contains("rodent") || $0.contains("insect") || $0.contains("vermin") }
        let hasCrossContamination = allDetails.contains { $0.contains("cross-contam") || $0.contains("raw") || $0.contains("ready-to-eat") }
        let hasStorageIssues = allDetails.contains { $0.contains("storage") || $0.contains("stored") || $0.contains("labelled") || $0.contains("dated") }

        // Determine trend
        let scores = inspections.prefix(3).map { RestaurantDataStore.computeTrustScore(for:
            RestaurantData(id: restaurant.id, name: restaurant.name, address: restaurant.address, type: restaurant.type, inspections: [$0])
        ) }
        let improving = scores.count >= 2 && scores[0] > scores[1]
        let declining = scores.count >= 2 && scores[0] < scores[1]
        let trendNote = improving ? "The trend is improving." : declining ? "The trend is declining." : ""

        var summary: String
        var concerns: String
        var recommendations: String
        var risk: String

        switch restaurant.trustLevel {
        case .safe:
            summary = "\(name) scored \(score)/100 based on \(inspections.count) inspection(s). The most recent inspection on \(latestDateStr) was a \(latestStatus) with \(latestViolationCount == 0 ? "no violations" : "\(latestViolationCount) minor violation(s)")."
            if totalViolations == 0 {
                concerns = "None — this restaurant has a clean inspection record across all \(inspections.count) visit(s)."
            } else {
                concerns = "Only minor issues noted. No crucial or significant violations on record."
            }
            recommendations = "You can order with confidence here. \(name) has consistently met food safety standards. \(trendNote)"
            risk = "LOW"

        case .caution:
            let topIssue = topViolation.map { " The most notable issue: \($0)." } ?? ""
            summary = "\(name) received a \(latestStatus) on \(latestDateStr) with \(latestViolationCount) violation(s), earning a trust score of \(score)/100.\(topIssue) \(trendNote)"

            var concernParts: [String] = []
            if crucialCount > 0 { concernParts.append("\(crucialCount) crucial") }
            if significantCount > 0 { concernParts.append("\(significantCount) significant") }
            let violationSummary = concernParts.isEmpty ? "" : " (\(concernParts.joined(separator: ", ")))"
            concerns = "Inspectors found \(totalViolations) total violation(s)\(violationSummary) across \(inspections.count) inspection(s)."

            var recs: [String] = []
            if hasTemperatureIssues {
                recs.append("Stick to freshly cooked, served-hot dishes — cold food storage was flagged by inspectors.")
            }
            if hasSanitationIssues {
                recs.append("Skip raw items like salads — sanitation practices were cited.")
            }
            if hasCrossContamination {
                recs.append("Avoid raw or undercooked items — cross-contamination was noted.")
            }
            if hasStorageIssues {
                recs.append("Ask about daily specials rather than pre-made items — food storage was a cited issue.")
            }
            if recs.isEmpty {
                recs.append("Opt for well-cooked dishes. Ask your server if issues from the \(latestDateStr) inspection have been addressed.")
            }
            recommendations = recs.joined(separator: " ")
            risk = "MODERATE"

        case .danger:
            let topIssue = topViolation.map { " Inspectors specifically flagged: \($0)." } ?? ""
            summary = "\(name) scored \(score)/100 with a \(latestStatus) on its most recent inspection (\(latestDateStr)). \(latestViolationCount) violation(s) were found, including \(crucialCount) crucial issue(s).\(topIssue)"

            var concernParts: [String] = []
            for v in (recentCrucial + recentSignificant).prefix(2) {
                concernParts.append(v.detail)
            }
            concerns = concernParts.isEmpty
                ? "Multiple food safety failures documented. \(crucialCount) crucial and \(significantCount) significant violation(s) total."
                : concernParts.joined(separator: ". ") + "."

            var recs: [String] = []
            if hasPestIssues {
                recs.append("Pest activity was documented — strongly consider dining elsewhere.")
            }
            if hasTemperatureIssues {
                recs.append("Do not order cold or raw items — temperature control failures were found.")
            }
            if hasSanitationIssues {
                recs.append("Avoid anything that requires manual handling — sanitation violations are on record.")
            }
            if hasCrossContamination {
                recs.append("Skip raw or undercooked items entirely — cross-contamination was flagged.")
            }
            if recs.isEmpty || !hasPestIssues {
                recs.append("Check the Nearby Safer Options section below for alternatives with better records.")
            }
            recommendations = recs.joined(separator: " ")
            risk = "HIGH"
        }

        if !dietary.isEmpty {
            recommendations += " Note: you indicated \(dietary.summary) — always confirm ingredients with your server."
        }

        // Generate weather/time tips from context
        var weatherTip = "N/A"
        if let w = context.weather {
            if w.temperature < 0 {
                weatherTip = "It's \(Int(w.temperature))°C outside — hot, freshly cooked meals are both the warmest and safest choice."
            } else if w.temperature > 25 {
                weatherTip = "It's \(Int(w.temperature))°C outside — warm weather increases bacterial growth risk in improperly stored cold items."
            } else {
                weatherTip = "Current conditions (\(Int(w.temperature))°C, \(w.condition)) don't add significant food safety risk."
            }
        }

        let timeTip = context.mealPeriod.safetyNote

        var allergenWarning = "No specific allergen concerns."
        if !dietary.allergens.isEmpty {
            let allergenList = dietary.allergens.map(\.label).joined(separator: ", ")
            if hasSanitationIssues || hasCrossContamination {
                allergenWarning = "You flagged \(allergenList) allergies. This restaurant has sanitation/handling violations — extra caution recommended for cross-contamination. Ask staff about preparation procedures."
            } else {
                allergenWarning = "You flagged \(allergenList) allergies. No specific allergen-related violations on record, but always confirm with your server."
            }
        }

        return AdvisorResult(
            summary: summary,
            concerns: concerns,
            recommendations: recommendations,
            riskLevel: risk,
            weatherTip: weatherTip,
            timeTip: timeTip,
            allergenWarning: allergenWarning,
            rawResponse: "[Offline analysis — based on inspection data]"
        )
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "API request failed (HTTP \(code))"
        case .parseError: return "Could not parse API response"
        }
    }
}
