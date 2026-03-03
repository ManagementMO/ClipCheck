# App Clip Constraints

Real App Clips have hard constraints enforced by iOS. This simulator replicates the important ones so you can design within the same boundaries.

## URL-Based Invocation

App Clips are always triggered by a URL. No app icon. No way to "open" a clip manually.

In the real world, that URL comes from:

- **QR Code** — printed on a physical surface (menu, sign, poster, product)
- **NFC Tag** — embedded in an object (tap your phone to a sticker, card, or device)
- **Safari Smart Banner** — appears when visiting a website with an associated clip
- **Messages / SMS** — a link shared in iMessage or SMS
- **Apple Maps** — location-based clip cards
- **Siri Suggestions** — iOS surfaces recently used clips
- **App Clip Codes** — Apple's custom visual codes

**In this simulator:** The InvocationConsole replaces all of these. Type a URL and tap send.

## 15 MB Size Limit

Real App Clips must be under 15 MB. No large assets, no bundled ML models, no video files.

**In this simulator:** Not enforced, but keep it in mind.

## Ephemeral Lifecycle

App Clips are not installed. They appear, do their job, and disappear.

- **No persistent storage** across sessions
- **No login flows** — users won't create accounts for a 30-second experience
- **No onboarding** — no tutorials, no walkthrough screens
- **No push notifications** (unless explicitly granted, which is rare)
- **No background processing** — when the user leaves, the clip is done

## The 30-Second Moment

Apple's guideline: an App Clip should deliver value in under 30 seconds. The user scans something, does something, puts their phone away.

**In this simulator:** The MomentTimer counts seconds. Green = good. Yellow (20s+) = pushing it. Red (30s+) = too complex for a clip.

## Single Focused Task

An App Clip does one thing. Not a mini-app with tabs.

- Ordering a coffee: yes
- A full restaurant menu with filters and favorites: no
- Checking into a location: yes
- A full event management dashboard: no

## The Key Question

> Would the user install a full app for this? If yes, it's probably an app.
> Would the user NOT install an app but still want this? That's a clip.
