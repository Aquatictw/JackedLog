# Feature Landscape: Flutter UI Enhancements

**Domain:** Mobile fitness app UI/UX patterns
**Researched:** 2026-02-02
**Confidence:** MEDIUM (verified with official docs and multiple sources)

---

## Feature 1: Drag-and-Drop Note Reordering

### Expected UX Patterns

**Table Stakes - What Users Expect:**

| Pattern | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Long-press to initiate drag | iOS/Android standard gesture | Low | 300-500ms delay prevents accidental drags while scrolling |
| Haptic feedback on pickup | Confirms action registered | Low | Use `HapticFeedback.mediumImpact()` at drag start |
| Visual lift (elevation + scale) | Object feels "grabbed" | Low | Material: 8dp elevation, slight scale to 1.02-1.05 |
| Ghost/placeholder at original position | Shows where item came from | Medium | Semi-transparent or outline of original item |
| Other items animate aside | Preview of drop result | Medium | ~100ms animation with easing, not instant |
| Haptic bump on valid drop zone | Confirms successful placement | Low | Light haptic as item settles |
| Snap-to-position on release | Polished feel | Low | Quick 100ms animation to final position |

**Differentiators - What Makes It Great:**

| Pattern | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Drag handles for clarity | Obviates "how do I reorder?" | Low | Icon button at leading/trailing edge |
| Auto-scroll at edges | Enables reordering long lists | Medium | flutter_reorderable_grid_view handles this |
| Visual drop zone expansion | Magnetic snap feel | Medium | Expand hit target beyond visible border |
| Undo snackbar after reorder | Safety net for mistakes | Low | "Reordered. Undo?" with 5s timeout |

**Anti-Features - What NOT to Build:**

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Drag mode toggle button | Adds friction, feels dated | Use long-press like iOS/Android native |
| Instant position swap without animation | Feels jarring, disorienting | Animate items sliding 100ms |
| Drag sensitivity too high | Accidental reorders while scrolling | Add 300ms long-press delay |
| No haptic feedback | Interaction feels disconnected | Add feedback at pickup and drop |
| Requiring precision placement | Frustrating on touch | Use large hit targets, snap-to behavior |

### Implementation Notes for Notes Grid

**Current state:** Notes page uses `GridView.builder` without reordering capability.

**Recommended approach:**
1. Use `flutter_reorderable_grid_view` package for grid-based reorder
2. Add `sequence` column to notes table (integer, default to creation order)
3. Long-press initiates drag (mobile standard)
4. Apply `proxyDecorator` for elevation effect during drag
5. Persist sequence on `onReorder` callback

**Key Interactions:**

```
Drag Start:
- Long press 300-500ms triggers
- HapticFeedback.mediumImpact()
- Item elevates (8dp shadow) and scales slightly (1.03x)
- Other items maintain position initially

During Drag:
- Items slide aside as drag position changes (100ms animation)
- Auto-scroll triggers at screen edges
- Original position shows ghost/outline

Drop:
- HapticFeedback.lightImpact()
- Item snaps to position (100ms ease-out)
- Persist new sequence to database
- Optional: Show undo snackbar
```

**Edge Cases to Handle:**

| Edge Case | Expected Behavior |
|-----------|------------------|
| Single note | No reorder affordance needed |
| Drag cancelled (release at original) | Item settles back, no database update |
| Scroll during drag | Allow scrolling, maintain drag |
| Search filter active | Either disable reorder or reorder within filtered results |
| Concurrent edit (another note modified) | Sequence update should be atomic |

### Sources

- [NN/g Drag-Drop UX](https://www.nngroup.com/articles/drag-drop/) - Animation timing, visual feedback (HIGH confidence)
- [Flutter ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) - Official API (HIGH confidence)
- [flutter_reorderable_grid_view](https://pub.dev/packages/flutter_reorderable_grid_view) - Grid support (MEDIUM confidence)
- [Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/drag-and-drop-ux/) - Best practices (MEDIUM confidence)

---

## Feature 2: Edit Historical/Completed Workout

### Expected UX Patterns

**Table Stakes - What Users Expect:**

| Pattern | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Direct edit access | Users need to fix mistakes | Medium | Tap-to-edit is standard |
| Confirmation for destructive changes | Prevent accidental data loss | Low | Dialog for delete, not for value edits |
| Same UI as active workout | Consistency, familiarity | Medium | Mirror start_plan_page patterns |
| Changes save immediately or explicitly | Clear save model | Low | Auto-save with "Updated" confirmation |
| Visual distinction from active workout | Avoid confusion | Low | Header badge: "Editing Past Workout" |

**Differentiators - What Makes It Great:**

| Pattern | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Undo/revert option | Safety net for accidents | Medium | "Revert all changes" option |
| Change history indicator | Transparency | High | Show when workout was last modified |
| Inline editing without mode switch | Reduced friction | Medium | Tap field to edit directly |
| Validation feedback | Prevent invalid data | Low | Same validation as active workout |

**Anti-Features - What NOT to Build:**

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Read-only historical view | Blocks legitimate corrections | Allow editing with appropriate safeguards |
| Delete and re-add workflow | Too much friction (Samsung Health model) | Allow direct field editing |
| Overly strict validation | Historical data may be legitimate edge cases | Warn but allow saving |
| Confirmation for every change | Modal fatigue | Confirm only destructive (delete) actions |
| Hidden edit option | Users can't find it | Clear "Edit" button/affordance |

### Edit Workout Features Breakdown

**WORKOUT-01: Edit workout name**

| Requirement | Implementation |
|-------------|----------------|
| Trigger | Tap workout title or edit icon |
| UI | AlertDialog with text field |
| Validation | Non-empty string |
| Save | Update workouts table, show "Updated" snackbar |
| Undo | Not needed (non-destructive) |

**WORKOUT-02: Edit workout exercises (add/remove/reorder)**

| Requirement | Implementation |
|-------------|----------------|
| Add exercise | Same ExercisePickerModal as start_plan_page |
| Remove exercise | Swipe-to-delete OR delete button with confirmation |
| Reorder exercises | Same ReorderableListView pattern as start_plan_page |
| Edge case | Removing exercise removes its sets from history |
| Confirmation | Required for remove (destructive) |

**WORKOUT-03: Edit workout sets**

| Requirement | Implementation |
|-------------|----------------|
| Edit values | Tap set row to open EditSetPage (existing) |
| Add set | Same SetRow pattern as active workout |
| Delete set | Swipe or delete icon, confirmation dialog |
| Set type changes | Warmup/working/drop-set toggle (like active) |

**WORKOUT-04: Move selfie to edit panel**

| Requirement | Implementation |
|-------------|----------------|
| Location | Within edit workout view, not separate action |
| Actions | Add/change/remove selfie |
| Existing behavior | Keep camera/gallery picker pattern |

### UI/UX Recommendations

**Entry Point:**
- Add "Edit" action button to WorkoutDetailPage app bar
- OR: Make existing "Resume" behavior contextual (Resume if recent, Edit if old)

**Edit Mode Distinction:**
```
Visual cues for "editing past workout":
- Header shows "Editing: [Workout Name]"
- Subtle background tint or banner
- "Completed [date]" reminder visible
- Save/Done button clearly visible
```

**Consistency with start_plan_page:**

Mirror these patterns from the active workout:
- Exercise cards with expansion
- Add Set button appearance
- Reorder mode toggle
- Notes section
- Superset management

Different from active workout:
- No rest timer integration
- No "End Workout" button (already ended)
- Date/time shown as historical, not elapsed
- "Done" instead of "End Workout"

### Confidence Assessment

| Aspect | Confidence | Reason |
|--------|------------|--------|
| Edit name | HIGH | Simple, low-risk feature |
| Add/remove exercises | MEDIUM | Database cascade implications |
| Reorder exercises | HIGH | Already implemented in start_plan_page |
| Edit sets | HIGH | EditSetPage already exists and works |
| Selfie move | HIGH | UI reorganization only |

### Sources

- [Google Fit Edit Activity](https://support.google.com/fit/answer/6223934) - Edit workflow reference (MEDIUM confidence)
- [MapMyFitness Edit Workout](https://support.mapmyfitness.com/hc/en-us/articles/1500009118702-Edit-or-Delete-a-Workout) - Edit capability pattern (MEDIUM confidence)
- [UX Movement Destructive Actions](https://uxmovement.com/buttons/how-to-design-destructive-actions-that-prevent-data-loss/) - Confirmation patterns (MEDIUM confidence)
- Existing codebase: start_plan_page.dart, edit_set_page.dart (HIGH confidence)

---

## Feature 3: Total Workout Time Stat Card

### Expected UX Patterns

**Table Stakes - What Users Expect:**

| Pattern | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Clear duration format | Instant comprehension | Low | "12h 45m" or "12.75 hours" |
| Period-sensitive calculation | Matches other stats | Low | Sum duration for selected period |
| Consistent card styling | Visual coherence | Low | Match existing StatCard component |
| Responsive to period changes | Interactive feel | Low | Update when period selector changes |

**Differentiators - What Makes It Great:**

| Pattern | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Per-day average alongside total | Context for the number | Low | "Total 12h 45m (avg 1h 17m/workout)" |
| Comparison to previous period | Progress indication | Medium | "+15% vs last month" |
| Animated count-up on load | Micro-interaction delight | Low | Number animates from 0 |
| Trend indicator icon | Quick direction read | Low | Arrow up/down/neutral |

**Anti-Features - What NOT to Build:**

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Overly precise display (12:45:32) | Unnecessary precision clutter | Round to hours and minutes |
| Vague display ("about 13 hours") | Lacks specificity for fitness tracking | Use exact hours + minutes |
| Separate page for this stat | Over-engineering | Integrate in existing overview |
| Complex time breakdown chart | Scope creep | Keep as simple stat card first |

### Duration Display Format Recommendations

**Recommended Format:**

```
Total: 12h 45m
- Clear, scannable
- Handles edge cases gracefully
- Matches existing duration display in app
```

**Format Rules:**

| Duration Range | Display Format | Example |
|----------------|----------------|---------|
| < 1 hour | Minutes only | "45m" |
| 1-24 hours | Hours + minutes | "3h 15m" |
| 24+ hours | Hours + minutes | "127h 30m" |
| Zero workouts | Explicit zero | "0h" or "--" |

**Singular/Plural:** Not needed with abbreviated format ("1h" not "1 hour")

### Implementation Recommendations

**Query:**
```sql
SELECT SUM(
  CASE
    WHEN end_time IS NOT NULL
    THEN (end_time - start_time)
    ELSE 0
  END
) as total_duration
FROM workouts
WHERE start_time >= [period_start_timestamp]
```

**Edge Cases:**

| Edge Case | Handling |
|-----------|----------|
| Workout without end_time | Exclude from sum (incomplete) |
| Very long workout (12+ hours) | Include (may be legitimate) |
| Zero workouts in period | Show "0h" or "--" |
| All Time period | Sum all completed workouts |

**Card Placement:**
- Add as fifth card in stats grid
- Icon: `Icons.schedule` or `Icons.access_time`
- Color: Match theme tertiary or distinct from existing 4

**Existing StatCard Interface:**
```dart
StatCard(
  icon: Icons.schedule,
  label: 'Total Time',
  value: '12h 45m',  // Formatted duration
  color: colorScheme.tertiary,
)
```

### Sources

- [UX Pickle Duration Display](https://uxpickle.com/how-to-display-duration-hhmm-so-it-isnt-confusing/) - Format recommendations (MEDIUM confidence)
- [Prototypr Time in UI](https://blog.prototypr.io/expressing-time-in-ui-ux-design-5-rules-and-a-few-other-things-eda5531a41a7) - Best practices (MEDIUM confidence)
- Existing codebase: stat_card.dart, overview_page.dart (HIGH confidence)

---

## Good vs Great Implementation Summary

### What Makes These Features Feel Polished vs Janky

**Drag-Drop Reordering:**

| Janky | Polished |
|-------|----------|
| Instant position swap | Items animate smoothly aside (~100ms) |
| No pickup feedback | Haptic bump + visual elevation |
| Precise placement required | Generous hit targets, magnetic snap |
| Accidental triggers while scrolling | 300ms long-press delay |
| No indication of draggable | Subtle drag handle or affordance |

**Edit Completed Workout:**

| Janky | Polished |
|-------|----------|
| Modal per edit | Inline editing, single save |
| Confirm every change | Confirm only destructive actions |
| Different UI than active workout | Same patterns, clear distinction |
| No visual distinction | "Editing Past Workout" header |
| Changes silently saved | "Updated" snackbar confirmation |

**Stats Display:**

| Janky | Polished |
|-------|----------|
| "12:45:32" format | "12h 45m" readable format |
| Static number | Animated count-up micro-interaction |
| Misaligned with other cards | Consistent card styling |
| Missing for edge cases | Handles zero/null gracefully |

---

## Feature Dependencies

```
Drag-Drop Reordering:
- Requires: sequence column in notes table
- Enables: User-defined note organization

Edit Completed Workout:
- Requires: Edit mode UI (new or adapted from start_plan_page)
- Shares: ExercisePickerModal, EditSetPage, SetRow components
- Database: Same gym_sets and workouts tables

Total Time Stat:
- Requires: Completed workout duration data
- Shares: StatCard component, PeriodSelector integration
- Query: Simple aggregation, no new tables
```

---

## MVP Recommendations

**Prioritize:**
1. Total workout time stat card - Low complexity, high value, uses existing components
2. Edit workout name - Simple, addresses common user need
3. Edit sets (via existing EditSetPage) - Already working, just needs entry point

**Phase 2:**
4. Add/remove exercises in edit mode
5. Reorder exercises in edit mode (mirror start_plan_page)

**Phase 3:**
6. Drag-drop note reordering - Requires new package, sequence column

**Rationale:** Start with features that leverage existing code and have lowest risk. Drag-drop reordering is more complex (grid layout, new package, schema change) and can come later.

---

## Confidence Summary

| Feature | Overall Confidence | Notes |
|---------|-------------------|-------|
| Drag-drop reordering | MEDIUM | Patterns verified, package exists, implementation details need testing |
| Edit completed workout | HIGH | Patterns match active workout, mostly UI reorganization |
| Total time stat | HIGH | Simple aggregation, uses existing components |
