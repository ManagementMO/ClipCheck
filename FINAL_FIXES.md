# FINAL_FIXES.md — Pre-Submission Playbook

**Purpose:** This file is a detailed prompt for Claude Code to execute all fixes needed before opening the hackathon PR. Run this when you're ready to submit.

**IMPORTANT:** Do NOT switch the user's working branch or modify the `main` branch structure. Use a git worktree for the PR branch so the user's development environment stays untouched.

---

## Issues to Fix

### Issue 1: API Keys Exposed in Git

**Problem:** `reactiv_stuff/Submissions/clipcheck/Secrets.plist` contains real API keys (Gemini + ElevenLabs) and is tracked by git. `Secrets.example.plist` also contains a real ElevenLabs key on line 8. If committed to a PR, these will be publicly visible on GitHub.

**Fix (on PR branch only):**
1. Add `Secrets.plist` to `.gitignore`
2. Do NOT include `Secrets.plist` in the PR branch
3. In `Secrets.example.plist`, replace the ElevenLabs key `sk_7635e8cb98a6468872758c0de7de82b0eff03941888dd39d` with `YOUR_ELEVENLABS_API_KEY_HERE`

---

### Issue 2: Upstream Structure Mismatch

**Problem:** The upstream repo (`reactivapp/reactivapp-clipkit-lab`) has `ReactivChallengeKit/`, `Submissions/`, `scripts/`, `docs/` at the repo root. The user's fork moved everything into a `reactiv_stuff/` subdirectory. A PR from `main` would rename every upstream file — violating the submission rule "Did NOT edit files outside `Submissions/YourTeamName/`."

**Fix:** Create the PR branch from `upstream/main` in an **isolated git worktree** (not by switching branches). Then copy only the submission files into the correct location.

Steps:
```bash
# From /Users/mo/Downloads/ClipKit
git fetch upstream
git worktree add /tmp/clipcheck-pr-branch clipcheck-submission 2>/dev/null || \
  git worktree add -b clipcheck-submission /tmp/clipcheck-pr-branch upstream/main

# Copy submission files to the correct root-level location
mkdir -p /tmp/clipcheck-pr-branch/Submissions/clipcheck/
cp reactiv_stuff/Submissions/clipcheck/*.swift /tmp/clipcheck-pr-branch/Submissions/clipcheck/
cp reactiv_stuff/Submissions/clipcheck/*.json /tmp/clipcheck-pr-branch/Submissions/clipcheck/
cp reactiv_stuff/Submissions/clipcheck/Secrets.example.plist /tmp/clipcheck-pr-branch/Submissions/clipcheck/
cp reactiv_stuff/Submissions/clipcheck/SUBMISSION.md /tmp/clipcheck-pr-branch/Submissions/clipcheck/
# Do NOT copy Secrets.plist (contains real API keys)
```

**CRITICAL:** Do NOT `git checkout` or switch branches in the main working directory (`/Users/mo/Downloads/ClipKit`). The user must stay on `main`. All PR branch work happens in the worktree at `/tmp/clipcheck-pr-branch/`.

---

### Issue 3: SUBMISSION.md Is Unfilled

**Problem:** `reactiv_stuff/Submissions/clipcheck/SUBMISSION.md` is still the blank template with unchecked boxes and empty fields.

**Fix:** Fill in all 5 required sections based on the ClipCheck implementation. Key facts to include:

- **Section 1 — Problem Framing:** Touchpoint = In-person / on-site interaction. Diners face an information gap — public health inspection data exists but is buried across scattered municipal websites. ClipCheck solves this at the moment of decision with a QR scan.

- **Section 2 — Proposed Solution:**
  - Invocation: QR Code on restaurant door/table/menu
  - URL pattern: `example.com/restaurant/:restaurantId/check`
  - Flow: Scan QR → optional dietary selector → animated trust score gauge (0-100, color-coded) → inspection timeline → expandable violation cards → AI safety advisor (Gemini) → voice briefing (ElevenLabs TTS) → menu recommendations → nearby safer alternatives
  - 8-hour notification: Follow-up nudge for undecided diners

- **Section 3 — Platform Extensions:** None required. Works within existing App Clip constraints.

- **Section 4 — Prototype Description:** Working ClipExperience with: trust score gauge, inspection timeline, violation cards, Gemini AI advisor with offline fallback, ElevenLabs voice briefing with AVSpeechSynthesizer fallback, dietary profile selector (8 allergens + 4 preferences), menu recommendation cards, nearby alternatives, QR scanner + generator. 10 sample restaurants with realistic inspection data.

- **Section 5 — Impact Hypothesis:** In-person channel. Eliminates information gap at decision time. High-scoring restaurants gain trust signal. Estimated 40%+ scan rate at tables, 15%+ switch rate for danger-level restaurants. On-site moment is where the gap is widest and the decision most immediate.

- **URL pattern header:** Change from `example.com/clipcheck/:param` to `example.com/restaurant/:restaurantId/check`

- **Demo Video / Screenshots:** Leave as `Link: ___` (user will add these manually)

---

### Issue 4: URL Pattern Mismatch in SUBMISSION.md

**Problem:** Line 3 says `example.com/clipcheck/:param` but the actual ClipCheck code uses `example.com/restaurant/:restaurantId/check`.

**Fix:** Already covered in Issue 3 above — update line 3 of SUBMISSION.md.

---

### Issue 5: No Submission Branch

**Problem:** User works on `main`. Need a clean branch for the PR against `upstream/main`.

**Fix:** Already covered in Issue 2 — the worktree approach creates the `clipcheck-submission` branch from `upstream/main` without disrupting the user's working directory.

---

## Full Execution Script

When ready to submit, Claude Code should execute the following sequence. **All work happens in the worktree, NOT in the main repo directory.**

```
1. Fix SUBMISSION.md locally first (on main, in reactiv_stuff/Submissions/clipcheck/)
   - Fill all 5 sections per Issue 3
   - Fix URL pattern per Issue 4

2. Sanitize Secrets.example.plist locally
   - Replace real ElevenLabs key with placeholder

3. Create worktree for PR branch
   - git fetch upstream
   - git worktree add -b clipcheck-submission /tmp/clipcheck-pr-branch upstream/main

4. Copy submission files to worktree (NO Secrets.plist)
   - All .swift files
   - All .json files
   - Secrets.example.plist (sanitized)
   - SUBMISSION.md (filled)

5. In the worktree, add Secrets.plist to .gitignore

6. In the worktree, run the registry generator
   - bash scripts/generate-registry.sh

7. In the worktree, verify build
   - xcodebuild -project ReactivChallengeKit/ReactivChallengeKit.xcodeproj \
     -scheme ReactivChallengeKit -sdk iphonesimulator \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

8. In the worktree, stage and commit
   - git add Submissions/clipcheck/ .gitignore
   - git add ReactivChallengeKit/ReactivChallengeKit/GeneratedSubmissions.swift
   - git add ReactivChallengeKit/ReactivChallengeKit/SubmissionRegistry.swift
   - Do NOT stage .claude/settings.local.json or any other files
   - Commit message: "Add ClipCheck submission — restaurant health inspection scoring clip"

9. Push and create PR
   - git push origin clipcheck-submission
   - gh pr create against upstream/main with:
     - Title: "Add ClipCheck — Restaurant Health Inspection Score Clip"
     - Body: summary of what ClipCheck does, link to demo video, checklist items

10. Clean up worktree
    - git worktree remove /tmp/clipcheck-pr-branch
```

## Verification Checklist

Before opening the PR, verify:
- [ ] `Secrets.plist` is NOT in the commit (gitignored)
- [ ] `Secrets.example.plist` has only placeholder keys
- [ ] SUBMISSION.md has all 5 sections filled
- [ ] URL pattern in SUBMISSION.md matches code (`example.com/restaurant/:restaurantId/check`)
- [ ] Only files in `Submissions/clipcheck/`, `.gitignore`, and auto-generated registry files are changed
- [ ] Build succeeds in the worktree
- [ ] PR is against `upstream/main`, not `origin/main`
- [ ] User's main branch and working directory are completely untouched
