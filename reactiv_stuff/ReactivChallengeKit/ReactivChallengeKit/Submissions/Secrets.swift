//  Secrets.swift
//  ClipCheck — Restaurant Safety Score via App Clip
//
//  Loads API keys from Secrets.plist so they are never hardcoded in source.
//  Copy Secrets.example.plist to Secrets.plist and fill in your real keys.

import Foundation

enum Secrets {
    private static let values: [String: String] = {
        let candidates = [
            Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            Bundle.main.url(forResource: "Secrets", withExtension: "plist", subdirectory: "clipcheck"),
        ]
        for case let url? in candidates {
            if let dict = NSDictionary(contentsOf: url) as? [String: String] {
                print("[Secrets] Loaded from: \(url.lastPathComponent)")
                return dict
            }
        }
        print("[Secrets] WARNING: Secrets.plist not found in bundle. API features will use fallback behavior.")
        return [:]
    }()

    static var geminiAPIKey: String {
        let key = values["GEMINI_API_KEY"] ?? ""
        if key.isEmpty || key == "YOUR_GEMINI_API_KEY_HERE" {
            print("[Secrets] WARNING: GEMINI_API_KEY is missing or placeholder. Gemini features will use fallback behavior.")
        }
        return key
    }

    static var elevenLabsAPIKey: String {
        let key = values["ELEVENLABS_API_KEY"] ?? values["ELEVEN_LABS_API_KEY"] ?? ""
        if key.isEmpty || key == "YOUR_ELEVENLABS_API_KEY_HERE" {
            print("[Secrets] WARNING: ELEVENLABS_API_KEY is missing or placeholder. TTS features will be disabled.")
        }
        return key
    }
}
