//  RestaurantModels.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import SwiftUI

// MARK: - Colors

let safeColor = Color(red: 0.133, green: 0.773, blue: 0.369)    // #22C55E
let cautionColor = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
let dangerColor = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444

// MARK: - Trust Level

enum TrustLevel {
    case safe, caution, danger

    var color: Color {
        switch self {
        case .safe: return safeColor
        case .caution: return cautionColor
        case .danger: return dangerColor
        }
    }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .danger: return "High Risk"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.shield.fill"
        case .danger: return "xmark.shield.fill"
        }
    }
}

// MARK: - Inspection Status

enum InspectionStatus: String {
    case pass = "Pass"
    case conditionalPass = "Conditional Pass"
    case closed = "Closed"

    init(from raw: String) {
        switch raw {
        case "Pass": self = .pass
        case "Conditional Pass": self = .conditionalPass
        case "Closed": self = .closed
        default: self = .pass
        }
    }

    var baseScore: Double {
        switch self {
        case .pass: return 100
        case .conditionalPass: return 50
        case .closed: return 0
        }
    }

    var color: Color {
        switch self {
        case .pass: return safeColor
        case .conditionalPass: return cautionColor
        case .closed: return dangerColor
        }
    }

    var icon: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .conditionalPass: return "exclamationmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }

    var label: String { rawValue }
}

// MARK: - Infraction Severity

enum InfractionSeverity {
    case crucial, significant, minor, notApplicable

    init(from raw: String) {
        if raw.hasPrefix("C") { self = .crucial }
        else if raw.hasPrefix("S") { self = .significant }
        else if raw.hasPrefix("M") { self = .minor }
        else { self = .notApplicable }
    }

    var label: String {
        switch self {
        case .crucial: return "Crucial"
        case .significant: return "Significant"
        case .minor: return "Minor"
        case .notApplicable: return "N/A"
        }
    }

    var color: Color {
        switch self {
        case .crucial: return dangerColor
        case .significant: return cautionColor
        case .minor: return .gray
        case .notApplicable: return .secondary
        }
    }

    var penalty: Double {
        switch self {
        case .crucial: return 15
        case .significant: return 8
        case .minor: return 0
        case .notApplicable: return 0
        }
    }
}

// MARK: - Restaurant Data

struct RestaurantData: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let type: String
    let inspections: [Inspection]
}

// MARK: - Inspection

struct Inspection: Codable, Identifiable {
    let id: UUID
    let date: String
    let status: String
    let infractions: [Infraction]

    enum CodingKeys: String, CodingKey {
        case date, status, infractions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.date = try container.decode(String.self, forKey: .date)
        self.status = try container.decode(String.self, forKey: .status)
        self.infractions = try container.decode([Infraction].self, forKey: .infractions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(status, forKey: .status)
        try container.encode(infractions, forKey: .infractions)
    }

    var parsedStatus: InspectionStatus {
        InspectionStatus(from: status)
    }

    var parsedDate: Date {
        Self.dateFormatter.date(from: date) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Infraction

struct Infraction: Codable, Identifiable {
    let id: UUID
    let detail: String
    let severity: String
    let action: String

    enum CodingKeys: String, CodingKey {
        case detail, severity, action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.detail = try container.decode(String.self, forKey: .detail)
        self.severity = try container.decode(String.self, forKey: .severity)
        self.action = try container.decode(String.self, forKey: .action)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(detail, forKey: .detail)
        try container.encode(severity, forKey: .severity)
        try container.encode(action, forKey: .action)
    }

    var parsedSeverity: InfractionSeverity {
        InfractionSeverity(from: severity)
    }
}

// MARK: - Computed Properties on RestaurantData

extension RestaurantData {
    var trustScore: Int {
        RestaurantDataStore.computeTrustScore(for: self)
    }

    var trustLevel: TrustLevel {
        switch trustScore {
        case 70...100: return .safe
        case 40..<70: return .caution
        default: return .danger
        }
    }

    var lastInspectedLabel: String {
        guard let latest = inspections.first else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: latest.parsedDate)
    }
}
