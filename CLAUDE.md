# ClipCheck — Restaurant Safety Score via App Clip

## Context
Building an App Clip experience for Hack Canada 2026 using Reactiv's ClipKit Lab.
The App Clip lets users scan a QR code at any restaurant and instantly see public
health inspection data, AI safety recommendations, and voice briefings.

## Project Location
The ClipKit Lab repo is cloned at: ~/reactivapp-clipkit-lab/
My submission files go in: Submissions/[team-slug]/

## Key Files I'm Editing
- Submissions/[team-slug]/ClipCheckExperience.swift — Main experience
- Submissions/[team-slug]/SUBMISSION.md — Submission writeup
- Any additional Swift files I create in my submission folder

## Tech Constraints
- Swift 5.0+ / SwiftUI
- No external dependencies (no SPM, CocoaPods, or Carthage)
- iOS 16+ target
- Must implement the ClipExperience protocol
- Must be invokable via URL pattern
- Experience should deliver value in under 30 seconds (watch MomentTimer)
- No real App Clip entitlements needed — the simulator handles everything

## ClipExperience Protocol
```swift
protocol ClipExperience {
    var urlPattern: String { get }
    var clipName: String { get }
    var clipDescription: String { get }
    var teamName: String { get }
    var touchpoint: String { get }
    var invocationSource: String { get }
    
    @ViewBuilder
    func body(context: ClipContext) -> some View
}
```

## My URL Pattern
`example.com/restaurant/:restaurantId/check`

Test URL: `example.com/restaurant/baba-chicken-grill/check`

## Data
Pre-loaded JSON of restaurant inspection data bundled in the app.
Structured as: { restaurantId: { name, address, inspections: [{date, status, infractions: [{detail, severity}]}] } }

## Gemini API Integration
Call Gemini API via URLSession from Swift.
Send: restaurant name + inspection history + violation details
Receive: plain-English safety summary + menu recommendations + risk level

Endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=API_KEY
Method: POST
Body: { "contents": [{ "parts": [{ "text": "..." }] }] }

## ElevenLabs Integration
Text-to-speech via API for the "Tell Me" voice briefing button.
Endpoint: https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
Returns audio data that can be played with AVFoundation.

## UI Components to Build
1. TrustScoreGauge — Animated circular gauge (0-100), color transitions
2. InspectionTimeline — Horizontal scroll of color-coded inspection dots
3. ViolationCard — Expandable card showing infraction detail + severity badge
4. AIAdvisorCard — Gemini-generated safety recommendation
5. VoiceBriefingButton — Triggers ElevenLabs TTS
6. NearbyAlternatives — List of higher-scored restaurants nearby

## Design
- Clean, medical/safety aesthetic (not flashy commerce)
- White/light background with color-coded trust signals
- Green (#22C55E) = safe, Amber (#F59E0B) = caution, Red (#EF4444) = danger
- SF Pro font (system default)
- Rounded corners, subtle shadows, breathing room

## Demo Flow (CRITICAL PATH)
1. User enters URL in InvocationConsole: example.com/restaurant/baba-chicken-grill/check
2. ClipCheck experience opens
3. Trust score gauge animates from 0 to computed value (e.g., 62/100 amber)
4. Inspection timeline shows with color-coded dots
5. Tap most recent → violation details expand
6. AI Advisor card shows Gemini recommendation
7. Tap voice button → ElevenLabs reads summary
8. (Optional) Nearby alternatives section shows higher-scored restaurants

EVERYTHING serves this flow. No feature creep.

## Judging Criteria (Reactiv-specific)
| Criteria | Weight |
|----------|--------|
| Novelty of use case | 30% |
| Constraint awareness | 25% |
| Real-world trigger quality | 20% |
| Execution / demo | 15% |
| Scalability of the idea | 10% |