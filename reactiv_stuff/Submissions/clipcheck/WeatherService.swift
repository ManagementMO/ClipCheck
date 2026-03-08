//  WeatherService.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import Foundation

@Observable
final class WeatherService {
    private(set) var weather: WeatherData?
    private(set) var isLoading = false

    struct WeatherData {
        let temperature: Double
        let condition: String
        let weatherCode: Int

        var sfSymbol: String {
            switch weatherCode {
            case 0: return "sun.max.fill"
            case 1...3: return "cloud.fill"
            case 45, 48: return "cloud.fog.fill"
            case 51...57: return "cloud.drizzle.fill"
            case 61...67: return "cloud.rain.fill"
            case 71...77: return "cloud.snow.fill"
            case 80...82: return "cloud.heavyrain.fill"
            case 95...99: return "cloud.bolt.rain.fill"
            default: return "cloud.fill"
            }
        }

        var temperatureLabel: String {
            "\(Int(temperature))°C"
        }
    }

    func fetch() {
        guard !isLoading, weather == nil else { return }
        isLoading = true

        Task {
            do {
                let data = try await fetchFromAPI()
                await MainActor.run {
                    self.weather = data
                    self.isLoading = false
                }
            } catch {
                print("[WeatherService] Error: \(error), using fallback")
                await MainActor.run {
                    self.weather = Self.fallback
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Open-Meteo API (free, no key)

    private func fetchFromAPI() async throws -> WeatherData {
        // Waterloo, ON coordinates
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=43.4723&longitude=-80.5449&current=temperature_2m,weather_code")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.httpError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temp = current["temperature_2m"] as? Double,
              let code = current["weather_code"] as? Int else {
            throw WeatherError.parseError
        }

        return WeatherData(
            temperature: temp,
            condition: Self.conditionName(for: code),
            weatherCode: code
        )
    }

    // MARK: - Weather Code Mapping

    private static func conditionName(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Cloudy"
        }
    }

    // MARK: - Fallback (Waterloo in March)

    static let fallback = WeatherData(
        temperature: -5.0,
        condition: "Snowy",
        weatherCode: 71
    )
}

enum WeatherError: LocalizedError {
    case httpError
    case parseError

    var errorDescription: String? {
        switch self {
        case .httpError: return "Weather API request failed"
        case .parseError: return "Could not parse weather data"
        }
    }
}
