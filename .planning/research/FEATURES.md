# Feature Landscape: 5/3/1 Forever Block Programming

**Domain:** Strength training program tracking (5/3/1 Forever methodology)
**Researched:** 2026-02-11
**Confidence:** HIGH (domain rules well-defined, user's specific setup documented, existing codebase thoroughly analyzed)

---

## Current State Analysis

**What exists today:**
- Basic 5/3/1 calculator dialog (accessible via long-press on powerlifting exercises during workout)
- 4-week cycle: W1 (5s), W2 (3s), W3 (5/3/1), W4 (Deload) with AMRAP on last set of W1-W3
- Training Max editor dialog (4 lifts: Squat, Bench, Deadlift, OHP) stored in Settings table
- TM auto-increment after deload week (+2.5kg upper / +5kg lower)
- Week selector (W1-W4 SegmentedButton) with persistence in `fivethreeoneWeek` settings column
- Single global week counter shared across all lifts
- `_TrainingMaxBanner` on Notes page as entry point to TM editor

**What needs to change for Forever:**
- Single 4-week cycle becomes 11-week block with distinct phase types (Leader, Anchor, Deload, TM Test)
- Week selector (W1-W4) becomes block position tracker (week 1-11 across 5 phases)
- AMRAP-always calculator becomes context-aware (5's PRO for Leader, AMRAP for Anchor, special schemes for 7th Week)
- No supplemental work display becomes BBB 5x10 and FSL 5x5 calculated displays
- TM bump once per cycle becomes 3 bumps per block (after Leader 1, Leader 2, and Anchor)
- TM increment values change: +2.5kg/+5kg becomes +2.2kg/+4.5kg per user preference
- Notes page banner becomes entry point to full block overview page

---

## Table Stakes

Features users expect for 5/3/1 block tracking. Missing any of these means the feature is incomplete and users fall back to spreadsheets/markdown.

### TS-01: Block Overview Page

| Aspect | Detail |
|--------|--------|
| **What** | Dedicated page showing the full 11-week block structure with current position highlighted |
| **Why Expected** | Without seeing where you are in the block, you lose the whole point of structured periodization. Every 5/3/1 app (KeyLifts, Five3One, 531 BBB) shows cycle structure upfront. |
| **Complexity** | Medium |
| **Dependencies** | New database table for block state; replaces current `fivethreeoneWeek` single-integer tracking |

**Expected layout (vertical timeline, not horizontal -- works better on mobile per UX research):**

```
Block: BBB Leader / FSL Anchor
Started: Jan 13, 2026

[*] Leader 1    Week 1 - 5s PRO     [completed]
                Week 2 - 3s PRO     [completed]
                Week 3 - 5/3/1 PRO  [completed]
                TM: +2.2/+4.5kg

[ ] Leader 2    Week 4 - 5s PRO     [current] <-- highlighted
                Week 5 - 3s PRO
                Week 6 - 5/3/1 PRO
                TM: +2.2/+4.5kg

[ ] 7th Week    Week 7 - Deload

[ ] Anchor      Week 8 - 5s Week
                Week 9 - 3s Week
                Week 10 - 5/3/1 Week
                TM: +2.2/+4.5kg

[ ] 7th Week    Week 11 - TM Test
```

**Key UX decisions:**
- Vertical timeline (not horizontal stepper) -- mobile-friendly, shows all phases without scrolling
- Current week/phase visually prominent (filled circle, highlight color, "CURRENT" label)
- Completed phases show checkmark and are visually dimmed/de-emphasized
- Future phases visible but subdued
- Each phase shows its TM values (so user can see progression across the block)

### TS-02: Context-Aware Calculator

| Aspect | Detail |
|--------|--------|
| **What** | Calculator automatically shows correct set/rep scheme based on current block position |
| **Why Expected** | The whole point of block programming is different schemes per phase. A calculator that doesn't know Leader vs Anchor is useless for Forever. |
| **Complexity** | Medium |
| **Dependencies** | Block state (TS-01), refactors existing `FiveThreeOneCalculator` |

**Scheme by phase:**

| Phase | Week Pattern | Main Work | Last Set | Supplemental |
|-------|-------------|-----------|----------|-------------|
| Leader 1 | W1: 65/75/85% | 3x5 (all sets x5) | No AMRAP (5's PRO) | BBB 5x10 @ 60% TM |
| Leader 1 | W2: 70/80/90% | 3x5 (all sets x5) | No AMRAP (5's PRO) | BBB 5x10 @ 60% TM |
| Leader 1 | W3: 75/85/95% | 3x5 (all sets x5) | No AMRAP (5's PRO) | BBB 5x10 @ 60% TM |
| Leader 2 | Same as Leader 1 but with bumped TMs | Same | Same | Same |
| 7th Week Deload | 70/80/90/100% | 5, 3-5, 1, 1 | No AMRAP | None |
| Anchor | W1: 65/75/85% | 5/5/5+ | AMRAP last set | FSL 5x5 @ 65% |
| Anchor | W2: 70/80/90% | 3/3/3+ | AMRAP last set | FSL 5x5 @ 70% |
| Anchor | W3: 75/85/95% | 5/3/1+ | AMRAP last set | FSL 5x5 @ 75% |
| 7th Week TM Test | 70/80/90/100% | 5, 5, 5, 5 | No AMRAP | None |

**Calculator must clearly show:**
- Phase name and week label in header (e.g., "Leader 1 -- Week 2: 3s PRO")
- Whether AMRAP is active (prominent visual indicator, same border highlight as current)
- "5's PRO" label when all sets are straight 5s (Leader phases)
- Supplemental work section below main sets

### TS-03: Supplemental Work Display

| Aspect | Detail |
|--------|--------|
| **What** | Show supplemental sets (BBB or FSL) with calculated weights below main work in calculator |
| **Why Expected** | Supplemental work is integral to 5/3/1 Forever. Without it, users must calculate 60% of TM for BBB or remember first-set weight for FSL manually. Defeats the purpose of having a calculator. |
| **Complexity** | Low |
| **Dependencies** | Block state (TS-01) to know Leader vs Anchor |

**Display format in calculator:**

```
--- Main Work ---
Set 1: 65.0 kg x5   (65% TM)
Set 2: 75.0 kg x5   (75% TM)
Set 3: 85.0 kg x5   (85% TM)

--- Supplemental: BBB ---
5 x 10 @ 60.0 kg    (60% TM)
```

For Anchor FSL:
```
--- Main Work ---
Set 1: 65.0 kg x5   (65% TM)
Set 2: 75.0 kg x3   (75% TM)
Set 3: 85.0 kg x1+  (85% TM) AMRAP

--- Supplemental: FSL ---
5 x 5 @ 65.0 kg     (first set weight)
```

**Key points:**
- Supplemental section visually separated from main work (divider or card boundary)
- Weight pre-calculated and rounded to plate increments
- Label identifies the template (BBB / FSL) so user knows what they're doing
- For 7th Week phases: no supplemental section displayed

### TS-04: TM Progression Tracking Across Block

| Aspect | Detail |
|--------|--------|
| **What** | TMs auto-bump at correct points in the block and show history of TM values per phase |
| **Why Expected** | 5/3/1 Forever bumps TMs 3 times per block (after Leader 1, Leader 2, Anchor). Getting this wrong cascades incorrect weights through remaining phases. Users tracking in spreadsheets always have a TM column per cycle -- the app must match. |
| **Complexity** | Medium |
| **Dependencies** | Block state (TS-01), modifies existing TM storage |

**Bump schedule per block:**

```
Block start:  Squat=100, Bench=70, Deadlift=120, OHP=50
After Leader 1: Squat=104.5, Bench=72.2, Deadlift=124.5, OHP=52.2
After Leader 2: Squat=109, Bench=74.4, Deadlift=129, OHP=54.4
After Anchor:   Squat=113.5, Bench=76.6, Deadlift=133.5, OHP=56.6
```

**User's specific increments:** +2.2kg upper (Bench, OHP), +4.5kg lower (Squat, Deadlift)

**UX for bump:**
- When advancing past a cycle that triggers TM bump, show confirmation: "Cycle complete. Bump TMs? Squat +4.5kg (104.5 -> 109.0), Bench +2.2kg (72.2 -> 74.4)..."
- User confirms or can edit individual TMs before confirming (for cases where TM test indicates a reduction)
- Block overview page shows TM values at each phase boundary

### TS-05: Manual Week/Cycle Advancement

| Aspect | Detail |
|--------|--------|
| **What** | User can manually advance to the next week or cycle within the block |
| **Why Expected** | The app cannot know when the user actually trained. Unlike apps that auto-generate and schedule workouts, JackedLog is a logging tool -- the user decides when they've done a week's work and advances manually. This matches the existing W1-W4 week selector pattern. |
| **Complexity** | Low |
| **Dependencies** | Block state (TS-01) |

**UX options (recommend option A):**

**Option A: "Complete Week" button on block overview page**
- After training all 4 lifts for the current week, user taps "Complete Week"
- Advances to next week in the block
- If this crosses a cycle boundary, triggers TM bump flow (TS-04)
- Simple, explicit, matches mental model

**Option B: Auto-advance when calculator is opened on a new week (implicit)**
- Reject this. User might open calculator to look ahead, or might train out of order
- Explicit is better for a tool like this

**Edge cases:**
- User wants to skip a week (e.g., skip deload): allow advancing past it
- User wants to go back (made a mistake): allow navigating backward
- User wants to restart block: "New Block" button

### TS-06: Block Setup / Initialization

| Aspect | Detail |
|--------|--------|
| **What** | Flow to create a new 11-week block with starting TMs |
| **Why Expected** | User needs to set up initial TMs and start tracking. Without a clear setup flow, the block state has no starting point. |
| **Complexity** | Low-Medium |
| **Dependencies** | New database table, TM editor (existing) |

**Setup flow:**

```
1. User taps "Start New Block" (on block overview page or banner)
2. If existing TMs are set: "Use current TMs? Squat: 100kg, Bench: 70kg..."
   - Confirm: block created with those TMs
   - Edit: opens TM editor, then creates block
3. If no TMs set: opens TM editor first, then creates block
4. Block starts at Week 1 (Leader 1, Week 1)
```

**Key decisions:**
- Hardcoded template (user's specific Leader/Anchor setup) -- no template picker needed
- Re-use existing TrainingMaxEditor dialog for TM input
- Store block start date for reference
- Previous block data (if any) remains in history

---

## Differentiators

Features that make this better than a spreadsheet or markdown file. Not expected, but valued. These are what justify building an in-app feature versus the user continuing to track in their notes.

### DF-01: At-a-Glance Block Progress Badge

| Aspect | Detail |
|--------|--------|
| **What** | Small badge/chip on the Notes page banner (replacing current TrainingMaxBanner) showing current block position at a glance |
| **Value Proposition** | User sees "Leader 2, W2" without opening the block page. Quick context for "what am I doing today?" |
| **Complexity** | Low |
| **Dependencies** | Block state (TS-01) |

**Current:** Notes page shows "5/3/1 Training Max" banner that opens TM editor.
**Proposed:** Banner shows "5/3/1 Block: Leader 2 - Week 5" and opens block overview page.

### DF-02: Calculated Weight with Plate Breakdown Integration

| Aspect | Detail |
|--------|--------|
| **What** | Calculator shows both the weight AND the plate breakdown for each set |
| **Value Proposition** | Eliminates mental math at the rack. User sees "85.0 kg = 20kg bar + 2x20kg + 2x10kg + 2x2.5kg". Existing PlateCalculator widget can be reused. |
| **Complexity** | Low (widget exists) |
| **Dependencies** | Existing `plate_calculator.dart` widget |

### DF-03: TM History Graph per Lift

| Aspect | Detail |
|--------|--------|
| **What** | Graph showing TM progression for each lift across blocks over time |
| **Value Proposition** | Visualizes long-term strength progression through TM increases. More meaningful than 1RM graphs because TM is what you actually train with. |
| **Complexity** | Medium |
| **Dependencies** | TM history stored per bump event, existing graph infrastructure |

### DF-04: "What's Today?" Quick View

| Aspect | Detail |
|--------|--------|
| **What** | When opening the calculator from a specific exercise during a workout, it immediately shows the correct sets/weights for that exercise in the current block week -- no manual selection needed |
| **Value Proposition** | Zero-tap access to today's weights. Open calculator from Squat exercise -> immediately see "Leader 2, Week 5: Squat 70/80/90kg x5, then BBB 5x10 @ 60kg". Current calculator already knows which exercise it's opened from via `exerciseName` parameter. |
| **Complexity** | Low (extends existing pattern) |
| **Dependencies** | Block state (TS-01), exercise-to-lift mapping (already exists in `exerciseMapping`) |

### DF-05: Post-Block Summary

| Aspect | Detail |
|--------|--------|
| **What** | When completing the final week (TM Test), show a summary of the entire block: starting TMs, ending TMs, total weight progression, weeks completed |
| **Value Proposition** | Sense of accomplishment. Seeing "+13.5kg on Squat over 11 weeks" is motivating. Spreadsheets don't celebrate your progress. |
| **Complexity** | Low |
| **Dependencies** | Block state with TM history |

### DF-06: TM Test Validation Warning

| Aspect | Detail |
|--------|--------|
| **What** | During 7th Week TM Test, if user reports struggling with 100% TM x5, prompt them to consider reducing TM before starting next block |
| **Value Proposition** | Implements Wendler's key rule: "If you can't get 5 strong reps at 100% TM, your TM is too high." Apps that blindly auto-increment miss this crucial self-regulation. |
| **Complexity** | Low |
| **Dependencies** | TM Test phase detection, user input |

---

## Anti-Features

Things to deliberately NOT build. Building these would add complexity without matching the user's actual workflow, or would violate KISS/YAGNI principles.

### AF-01: Template Picker / Custom Program Builder

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Letting users choose from dozens of 5/3/1 Forever templates (BBB, BBS, SSL, God is a Beast, etc.) | User has ONE specific setup they run. Building a template system is massive scope. KeyLifts has 150+ templates and still gets complaints about bugs/incorrect percentages. | Hardcode the user's specific Leader (5's PRO + BBB) and Anchor (Original + FSL) templates. If they ever change programs, a code update is fine. |

### AF-02: Auto-Generated Workout Plans

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Generating full workout sessions with exercises pre-populated | JackedLog is a logging tool, not a plan generator. The user builds their own workouts. The 5/3/1 calculator is a reference tool opened during workouts, not a workout builder. | Keep calculator as reference. User logs sets manually as they always have. |

### AF-03: Assistance Work Tracking in Block System

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Tracking push/pull/legs assistance reps within the 5/3/1 block system | User explicitly stated "Accessories are bodybuilding style, not tracked in 5/3/1 system." Assistance is already logged as regular exercises in the workout. | Block system tracks only main lifts (Squat/Bench/Deadlift/OHP) and their supplemental work. Accessories remain as regular workout logging. |

### AF-04: Scheduling / Calendar Integration

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Mapping block weeks to calendar dates, setting training day reminders | JackedLog has no calendar. User trains when they train. Adding scheduling is a massive feature that doesn't match the app's philosophy. | Block tracks position (week/phase), not dates. User advances manually when ready. |

### AF-05: Joker Sets / Beyond 5/3/1 Extensions

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Adding Joker set calculations, Pyramid sets, or other Beyond 5/3/1 options | User's program doesn't use these. YAGNI. Can be added later if needed. | Support only 5's PRO, Original 5/3/1, BBB, FSL, 7th Week Deload, and 7th Week TM Test. |

### AF-06: Automatic Week Detection

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Automatically detecting which week the user is on based on logged workouts | Unreliable. User might log partial weeks, train out of order, miss sessions, or do extra sessions. Auto-detection creates more confusion than it solves. | Manual advancement. User explicitly marks a week as complete. Simple, predictable, no surprises. |

### AF-07: Multiple Concurrent Blocks

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Supporting multiple active blocks simultaneously | User runs one program at a time. Multiple blocks add UI complexity (which block? which lift belongs where?) for zero benefit. | Single active block. Start a new one when current is finished or abandoned. |

### AF-08: Block History / Archive System

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full history of all past blocks with drill-down into each | Over-engineering for v1.2. The real value is tracking the current block. Historical TMs are already visible through the existing TM values, and workout history is in the regular history tab. | Store minimal metadata (starting TMs, block start date) for the current block only. Expand later if needed. |

---

## Feature Dependencies

```
Block Setup (TS-06)
  |
  v
Block State (new DB table)
  |
  +---> Block Overview Page (TS-01)
  |       |
  |       +---> Progress Badge on Notes Banner (DF-01)
  |       +---> Manual Advancement (TS-05)
  |       |       |
  |       |       +---> TM Bump Flow (TS-04)
  |       |               |
  |       |               +---> Post-Block Summary (DF-05)
  |       |               +---> TM Test Validation (DF-06)
  |       |
  |       +---> TM History Graph (DF-03)
  |
  +---> Context-Aware Calculator (TS-02)
          |
          +---> Supplemental Work Display (TS-03)
          +---> "What's Today?" Quick View (DF-04)
          +---> Plate Breakdown Integration (DF-02)
```

**Critical path:** Block State (DB) -> Block Overview -> Context-Aware Calculator -> Supplemental Display

Everything else branches off these four.

---

## MVP Recommendation

**For the initial milestone, prioritize all Table Stakes features.** The differentiators can be layered in during the same milestone if time permits, but the table stakes ARE the feature -- without any one of them, the block tracking is incomplete and users revert to markdown.

### Phase ordering rationale:

**Phase 1: Block Data Model + Setup**
- New database table for block state (TS-06 foundation)
- Block setup flow (TS-06)
- This is pure backend -- everything else depends on it

**Phase 2: Block Overview Page + Navigation**
- Block overview page with vertical timeline (TS-01)
- Manual week advancement (TS-05)
- TM progression/bump flow (TS-04)
- Replace Notes page banner to point to block overview (DF-01)

**Phase 3: Context-Aware Calculator + Supplemental**
- Refactor existing calculator to be block-aware (TS-02)
- Add supplemental work display (TS-03)
- "What's Today?" auto-context (DF-04)

**Phase 4: Polish (if time)**
- Plate breakdown in calculator (DF-02)
- Post-block summary (DF-05)
- TM test validation warning (DF-06)

### Deferred indefinitely:
- TM history graph (DF-03) -- nice but not essential for v1.2
- All anti-features (AF-01 through AF-08)

---

## Confidence Summary

| Feature | Confidence | Reason |
|---------|------------|--------|
| Block structure (11 weeks) | HIGH | User provided exact specification; matches 5/3/1 Forever 2+1+1+1 pattern verified via multiple sources |
| Set/rep schemes per phase | HIGH | Standard 5/3/1 percentages well-documented; 5's PRO, Original, 7th Week protocols all verified |
| Supplemental work (BBB/FSL) | HIGH | Standard patterns: BBB = 5x10 @ percentage, FSL = 5x5 @ first set weight |
| TM bump values (+2.2/+4.5) | HIGH | User-specified values; differs from standard +2.5/+5 but this is their preference |
| 7th Week Deload scheme | MEDIUM | Multiple sources agree on 70/80/90/100% but rep schemes vary slightly across sources. User specified: 70%x5, 80%x3-5, 90%x1, 100%x1 |
| 7th Week TM Test scheme | MEDIUM | User specified 70/80/90/100% all x5. Some sources say 100%x3-5 for TM test. Using user's specification. |
| UX patterns (vertical timeline) | MEDIUM | Based on UX research for mobile steppers; vertical preferred over horizontal on mobile but not specific to fitness apps |
| Block overview as separate page | HIGH | Current Notes banner is natural entry point; block overview is the standard approach in KeyLifts, Five3One |

---

## Sources

- [KeyLifts 531 App](https://www.keylifts.com/) - Feature reference for 5/3/1 app capabilities (MEDIUM confidence)
- [Five/Three/One App](https://fivethreeone.app/) - Feature reference for cycle management (MEDIUM confidence)
- [Boostcamp BBB Guide](https://www.boostcamp.app/blogs/531-boring-but-big-app-program-guide) - Template implementation reference (MEDIUM confidence)
- [Lift Vault Leader/Anchor Guide](https://liftvault.com/resources/leader-anchor-cycles/) - Leader/Anchor cycle definitions (HIGH confidence)
- [T-Nation 7th Week Protocol Discussion](https://t-nation.com/t/confusion-on-7th-week-tm-test-after-anchor/246002) - TM Test protocol details (MEDIUM confidence)
- [The Fitness Wiki 5/3/1 Primer](https://thefitness.wiki/5-3-1-primer/) - 5/3/1 fundamentals reference (HIGH confidence)
- [UX Planet Progress Trackers](https://uxplanet.org/progress-trackers-in-ux-design-4319cef1c600) - Timeline/stepper UX patterns (MEDIUM confidence)
- [Eleken Stepper UI Examples](https://www.eleken.co/blog-posts/stepper-ui-examples) - Mobile stepper design patterns (MEDIUM confidence)
- Existing codebase: `five_three_one_calculator.dart`, `training_max_editor.dart`, `notes_page.dart`, `settings.dart` (HIGH confidence)
- User's project context and milestone specification (HIGH confidence)
