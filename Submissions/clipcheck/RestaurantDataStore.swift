//  RestaurantDataStore.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import Foundation

final class RestaurantDataStore {
    static let shared = RestaurantDataStore()

    private let index: [String: RestaurantData]

    var allRestaurants: [RestaurantData] {
        Array(index.values).sorted { $0.name < $1.name }
    }

    private init() {
        let list = Self.loadFromBundle() ?? []
        var dict: [String: RestaurantData] = [:]
        for restaurant in list {
            dict[restaurant.id] = restaurant
        }
        self.index = dict
    }

    func lookup(_ id: String) -> RestaurantData? {
        index[id.lowercased()]
    }

    func nearbyAlternatives(excluding id: String, limit: Int = 3) -> [RestaurantData] {
        Array(
            allRestaurants
                .filter { $0.id != id && $0.trustScore >= 70 }
                .sorted { $0.trustScore > $1.trustScore }
                .prefix(limit)
        )
    }

    // MARK: - Bundle Loading

    private static func loadFromBundle() -> [RestaurantData]? {
        // PBXFileSystemSynchronizedRootGroup preserves directory structure,
        // so try both flat and nested paths.
        let candidates = [
            Bundle.main.url(forResource: "restaurants", withExtension: "json"),
            Bundle.main.url(forResource: "restaurants", withExtension: "json", subdirectory: "clipcheck"),
        ]

        for case let url? in candidates {
            if let data = try? Data(contentsOf: url),
               let list = try? JSONDecoder().decode([RestaurantData].self, from: data) {
                return list
            }
        }

        return nil
    }

    // MARK: - Trust Score Algorithm

    /// Computes a 0-100 trust score based on:
    /// 1. Most recent inspection status (Pass=100, Conditional=50, Closed=0)
    /// 2. Crucial infractions (-15 each), Significant infractions (-8 each)
    /// 3. Trend direction over last 3 inspections (+5 improving, -10 declining)
    /// 4. Recency weighting (60% / 25% / 15% for last 3 inspections)
    static func computeTrustScore(for restaurant: RestaurantData) -> Int {
        let inspections = restaurant.inspections
        guard !inspections.isEmpty else { return 50 }

        let recent = Array(inspections.prefix(3))
        let weights: [Double] = [0.60, 0.25, 0.15]

        // Score each inspection individually
        let scores = recent.map { scoreInspection($0) }

        // Weighted average (recency)
        var weightedTotal = 0.0
        var weightSum = 0.0
        for (i, score) in scores.enumerated() {
            let w = i < weights.count ? weights[i] : 0.05
            weightedTotal += score * w
            weightSum += w
        }
        var finalScore = weightedTotal / weightSum

        // Trend direction: compare most recent to second most recent
        if scores.count >= 2 {
            if scores[0] > scores[1] {
                finalScore += 5   // improving
            } else if scores[0] < scores[1] {
                finalScore -= 10  // declining
            }
        }

        return max(0, min(100, Int(finalScore)))
    }

    /// Score a single inspection: base status score minus infraction penalties.
    private static func scoreInspection(_ inspection: Inspection) -> Double {
        let base = inspection.parsedStatus.baseScore

        var penalties = 0.0
        for infraction in inspection.infractions {
            penalties += infraction.parsedSeverity.penalty
        }

        return max(0, base - penalties)
    }
}
