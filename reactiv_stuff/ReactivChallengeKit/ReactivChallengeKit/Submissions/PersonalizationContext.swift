//  PersonalizationContext.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import Foundation

// MARK: - Meal Period

enum MealPeriod: String {
    case breakfast = "breakfast"
    case lunchRush = "lunch_rush"
    case afternoon = "afternoon"
    case dinnerRush = "dinner_rush"
    case lateNight = "late_night"

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunchRush: return "Lunch Rush"
        case .afternoon: return "Afternoon"
        case .dinnerRush: return "Dinner Rush"
        case .lateNight: return "Late Night"
        }
    }

    var safetyNote: String {
        switch self {
        case .breakfast:
            return "Early hours — fresh prep, lower volume, generally safer."
        case .lunchRush:
            return "Peak lunch — high turnover means fresher food, but more kitchen pressure."
        case .afternoon:
            return "Mid-afternoon — lower demand, food may have been sitting longer."
        case .dinnerRush:
            return "Dinner rush — similar to lunch, high turnover but more pressure."
        case .lateNight:
            return "Late night — limited fresh prep, more reheated items."
        }
    }

    var sfSymbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunchRush: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .dinnerRush: return "sunset.fill"
        case .lateNight: return "moon.fill"
        }
    }

    static func classify(_ date: Date = Date()) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        let time = hour * 60 + minute // minutes since midnight

        switch time {
        case 360..<630:   return .breakfast     // 6:00 - 10:29
        case 630..<840:   return .lunchRush     // 10:30 - 13:59
        case 840..<1020:  return .afternoon     // 14:00 - 16:59
        case 1020..<1260: return .dinnerRush    // 17:00 - 20:59
        default:          return .lateNight     // 21:00 - 5:59
        }
    }
}

// MARK: - Personalization Context

struct PersonalizationContext {
    let weather: WeatherService.WeatherData?
    let mealPeriod: MealPeriod
    let currentTime: Date
    let dietary: DietaryProfile

    init(
        weather: WeatherService.WeatherData? = nil,
        dietary: DietaryProfile = DietaryProfile(),
        time: Date = Date()
    ) {
        self.weather = weather
        self.mealPeriod = MealPeriod.classify(time)
        self.currentTime = time
        self.dietary = dietary
    }

    /// Formatted prompt fragment for Gemini
    var promptFragment: String {
        var lines: [String] = []
        lines.append("CURRENT CONTEXT:")

        if let w = weather {
            lines.append("- Weather: \(Int(w.temperature))°C, \(w.condition) in Waterloo")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        lines.append("- Time: \(formatter.string(from: currentTime)) (\(mealPeriod.label))")

        if !dietary.allergens.isEmpty {
            lines.append("- Diner's allergens: \(dietary.allergens.map(\.label).joined(separator: ", "))")
        } else {
            lines.append("- Diner's allergens: none specified")
        }

        if !dietary.preferences.isEmpty {
            lines.append("- Diner's dietary preference: \(dietary.preferences.map(\.label).joined(separator: ", "))")
        } else {
            lines.append("- Diner's dietary preference: none specified")
        }

        return lines.joined(separator: "\n")
    }
}
