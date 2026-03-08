## Team Name: ClipCheck
## Clip Name: ClipCheck
## Invocation URL Pattern: example.com/restaurant/:restaurantId/check

---

## What Great Looks Like

Your submission is strong when it is:
- **Specific**: one clear fan moment, one clear problem, one clear outcome
- **Clip-shaped**: value in under 30 seconds, no heavy onboarding
- **Business-aware**: connects to revenue (venue, online, or both)
- **Testable**: prototype actually runs in the simulator with your URL pattern

---

### 1. Problem Framing

Which user moment or touchpoint are you targeting?

- [ ] Discovery / first awareness
- [ ] Intent / consideration
- [ ] Purchase / conversion
- [x] In-person / on-site interaction
- [ ] Post-purchase / re-engagement
- [ ] Other: ___

What friction or missed opportunity are you solving for? (3-5 sentences)

ClipCheck targets the exact moment a diner is deciding whether to sit down, order, or leave. Public health inspection data already exists, but it is fragmented across municipal portals, hard to search on mobile, and effectively invisible at the restaurant door. That creates an information gap at the point of highest decision pressure. ClipCheck turns a posted QR code into an instant trust layer so diners can understand risk in seconds and restaurants with strong inspection records can benefit from that transparency.

### 2. Proposed Solution

**How is the Clip invoked?** (check all that apply)
- [x] QR Code (printed on physical surface)
- [ ] NFC Tag (embedded in object — wristband, poster, etc.)
- [ ] iMessage / SMS Link
- [ ] Safari Smart App Banner
- [ ] Apple Maps (location-based)
- [ ] Siri Suggestion
- [ ] Other: ___

**End-to-end user experience** (step by step):
1. A diner scans a ClipCheck QR code posted on a restaurant door, host stand, table tent, or menu.
2. The Clip opens directly into `example.com/restaurant/:restaurantId/check` and asks for an optional dietary profile if the user has allergens or preferences.
3. The diner sees an animated 0-100 trust score, recent inspection history, and expandable violation details with clear severity signals.
4. Gemini-powered safety guidance summarizes what matters, while a voice briefing can read the result aloud with a built-in fallback if network audio is unavailable.
5. The Clip highlights safer menu picks for the diner's profile and suggests nearby alternatives when a restaurant scores poorly.

**How does the 8-hour notification window factor into your strategy?**

If a diner scans but does not commit, the 8-hour window supports a follow-up reminder with the restaurant's score, top safety takeaway, or a prompt to revisit safer nearby options. The window is useful because the decision is highly local and time-sensitive: users may compare two places, walk away, and still act within the same meal window.

### 3. Platform Extensions (if applicable)

Does your solution require new Reactiv Clips capabilities that do not exist today? If so, describe them and explain why they are required.

None. ClipCheck fits inside the current Reactiv Clip model: URL invocation, a focused under-30-second flow, optional AI enrichment, and post-invocation notification strategy without requiring a full installed app.

### 4. Prototype Description

What does your working prototype demonstrate? Which screens/flows are implemented?

Minimum expectation:
- A working `ClipExperience`
- Invokable via your URL pattern in Invocation Console
- At least one complete user flow with a clear end state

The prototype is a working SwiftUI `ClipExperience` with a premium App Clip-style flow for restaurant safety screening. Implemented elements include: a landing experience, QR scanner and QR generator utilities, optional dietary profile selection with 8 allergen filters and 4 dietary preferences, an animated trust score gauge, a recent inspection timeline, expandable violation cards, Gemini-based safety analysis with offline fallback, ElevenLabs voice briefing with `AVSpeechSynthesizer` fallback, AI-assisted menu recommendations, nearby safer alternatives, and weather-aware personalization. The demo dataset includes 10 sample restaurants with realistic inspection histories and score variation.

### 5. Impact Hypothesis

How does this create measurable business impact? Be specific about:
- Which channel benefits (in-person, online, or both)?
- What conversion or engagement improvement do you estimate, and why?
- Why this touchpoint is the right place to intervene

The primary impact is on the in-person channel, where trust directly affects whether a guest stays, orders, or leaves. For high-scoring restaurants, ClipCheck acts as a conversion aid by turning invisible compliance into a visible trust signal at the table or storefront. For low-scoring locations, it creates a safer consumer decision path and a clear incentive for operators to improve. We estimate 40%+ scan engagement when QR codes are placed at tables or entrances, and a 15%+ behavior change rate for danger-level restaurants because the intervention happens at the exact moment the dining decision is made.

### Demo Video

Link: ___

### Screenshot(s)
