# ReactivChallengeKit

An App Clip simulator for Hack Canada. Build creative App Clip experiences without needing entitlements, Associated Domains, or an Apple Developer account.

App Clips are lightweight, instant experiences invoked by a URL — no install, no login, no onboarding. Apple designed them for "30-second moments." Most people only think of them as "scan to pay." **Your challenge: what else should App Clips be used for that nobody has built yet?**

## Setup

1. Clone this repository
2. Open `ReactivChallengeKit.xcodeproj` in Xcode 26+
3. Select an iPhone simulator
4. Build and Run (Cmd+R)

No dependencies. No SPM packages. If Xcode works, the project works.

## How to Build Your Clip

### Step 1: Create Your File

Duplicate `Examples/EmptyClipExperience.swift` and rename it.

### Step 2: Conform to the Protocol

```swift
struct MyClipExperience: ClipExperience {
    static let urlPattern = "myapp.com/action/:id"
    static let clipName = "My Clip"
    static let clipDescription = "One line about what it does."

    let context: ClipContext

    var body: some View {
        // Your SwiftUI UI here
        // Access context.pathParameters["id"] for the URL parameter
        // Access context.queryParameters for ?key=value pairs
    }
}
```

### Step 3: Register Your Clip

Open `Simulator/ClipRouter.swift` and add your type to `allExperiences`:

```swift
static let allExperiences: [any ClipExperience.Type] = [
    HelloClipExperience.self,
    MyClipExperience.self,  // <-- add this
]
```

### Step 4: Test It

Run the app, type your invocation URL in the console (e.g., `myapp.com/action/42`), and tap the send button. Or tap a registered clip card on the landing page.

## What You Get

| Component | What It Does |
|---|---|
| **InvocationConsole** | URL input with send button. Simulates how real clips are triggered by URLs. |
| **ClipRouter** | Matches URLs against registered patterns and extracts path parameters. |
| **ConstraintBanner** | "App Clip Preview — Get the full app" bar. Always visible, just like real clips. |
| **MomentTimer** | Seconds-since-invocation pill. Green < 20s, yellow < 30s, red >= 30s. |

## What You Bring

Everything else is yours. Use any iOS framework — URLSession, CoreLocation, MapKit, AVFoundation, CoreNFC, or any SwiftUI view.

No mock services are provided. You choose the domain, the data, and the experience.

## Project Structure

```
ReactivChallengeKit/
  App/
    ReactivChallengeKitApp.swift   # App entry point
  Simulator/
    SimulatorShell.swift           # Main container + clip host
    ClipRouter.swift               # URL pattern matching
    LandingView.swift              # Home screen with clip cards
    InvocationConsole.swift        # URL input
    ConstraintBanner.swift         # Download banner
    MomentTimer.swift              # Elapsed time overlay
  Protocol/
    ClipExperience.swift           # Protocol you conform to
    ClipContext.swift              # URL data passed to your clip
  Examples/
    HelloClipExperience.swift      # Working example (protocol demo)
    TrailCheckInExperience.swift   # Working example (non-trivial clip)
    EmptyClipExperience.swift      # Your starting template
```

## Challenge Rules

1. Your clip must be invoked via URL (use the InvocationConsole)
2. Your experience should deliver value in under 30 seconds (watch the timer)
3. Your clip should make sense as a no-install, ephemeral experience
4. Fill out `SUBMISSION.md` with your team info and idea description
5. Read `CONSTRAINTS.md` to understand real App Clip constraints

## Judging Criteria

| Criteria | Weight |
|---|---|
| Novelty of use case | 30% |
| Constraint awareness | 25% |
| Real-world trigger quality | 20% |
| Execution / demo | 15% |
| Scalability of the idea | 10% |

The question is NOT "can you build an iOS app?" The question is: **"what experience fits the shape of an App Clip that nobody has thought of?"**
