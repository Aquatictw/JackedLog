---
phase: quick-007
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/fivethreeone/block_overview_page.dart
  - lib/widgets/five_three_one_calculator.dart
autonomous: true

must_haves:
  truths:
    - "Completed blocks show TMs in a readable multi-line layout with labels (Squat, Bench, Deadlift, OHP) and 'Training Max' header"
    - "TM card on block overview has more vertical breathing room (top/bottom padding) while Complete Week button remains visible without scrolling"
    - "Calculator dialog's TM input section has tighter spacing below it, and supplemental work has a 'Supplemental Work' label"
    - "Calculator shows current Leader/Anchor cycle position when in block mode"
  artifacts:
    - path: "lib/fivethreeone/block_overview_page.dart"
      provides: "Improved completed block TM display and TM card padding"
    - path: "lib/widgets/five_three_one_calculator.dart"
      provides: "Tighter TM spacing, supplemental label, cycle position indicator"
---

<objective>
Polish 5/3/1 UI across Block Progress page and Calculator dialog with four targeted improvements: readable completed block TMs, better TM card vertical spacing, tighter calculator layout with supplemental label, and cycle position display.

Purpose: Improve readability and information density of existing 5/3/1 UI
Output: Updated block_overview_page.dart and five_three_one_calculator.dart
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/fivethreeone/block_overview_page.dart
@lib/widgets/five_three_one_calculator.dart
@lib/fivethreeone/schemes.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Improve Block Overview page (completed blocks TM display + TM card padding)</name>
  <files>lib/fivethreeone/block_overview_page.dart</files>
  <action>
  Two changes in `_CompletedBlockHistory`:

  1. Replace the single-line TM display (lines 569-573: `'S ${_formatTm(block.squatTm)}  B ${_formatTm(block.benchTm)}  D ${_formatTm(block.deadliftTm)}  P ${_formatTm(block.pressTm)} ${block.unit}'`) with a more readable layout:
     - Add a subtle "Training Max" label (bodySmall, muted color) above the TM values
     - Display TMs in a 2x2 grid or 4-column Row using full labels: "Squat", "Bench", "Deadlift", "OHP"
     - Each lift shows the label on top (bodySmall, muted) and value+unit below (bodyMedium, bold)
     - Use a Wrap or Row with Expanded children so it fits cleanly

  2. In `_TmCard.build()`, increase the outer Padding from `EdgeInsets.all(12)` (line 344) to `EdgeInsets.symmetric(horizontal: 12, vertical: 16)` to give the Training Max section more vertical breathing room on the block overview page.

  Keep the InkWell + chevron_right tap-to-view-summary behavior intact.
  </action>
  <verify>Read the file and confirm: completed blocks use labeled multi-line TM layout; _TmCard has increased vertical padding.</verify>
  <done>Completed blocks display TMs with full lift names in a structured grid layout with "Training Max" header. TM card has more vertical padding.</done>
</task>

<task type="auto">
  <name>Task 2: Calculator dialog improvements (tighter TM spacing, supplemental label, cycle position)</name>
  <files>lib/widgets/five_three_one_calculator.dart</files>
  <action>
  Three changes in the calculator dialog:

  1. **Reduce spacing after TM input section:** Change the `SizedBox(height: 24)` on line 399 (between TM input and week selector) to `SizedBox(height: 16)`. This tightens the gap below the Training Max input.

  2. **Add "Supplemental Work" label above supplemental section:** In the supplemental section (lines 571-586), add a "Supplemental Work" title before the existing supplemental text. Structure:
     ```
     const SizedBox(height: 16),
     Divider(color: colorScheme.outlineVariant),
     const SizedBox(height: 8),
     Text('Supplemental Work', style: titleMedium bold),
     const SizedBox(height: 4),
     Builder(builder: ...) // existing supplemental text
     ```
     This replaces the current structure that just has the divider and then immediately the supplemental weight text.

  3. **Show cycle position in block mode:** In the header section (lines 310-363), when `_isBlockMode` is true, add the cycle position info below the exercise name subtitle. Use `cycleNames[_blockCycleType]` from schemes.dart to show something like "Leader 1" or "Anchor". Display it as a small chip/badge next to the exercise name, or as a third line in the header subtitle area. Example: add after the exercise name Text widget (line 349) a third Text showing `'${cycleNames[_blockCycleType]} - Week $_blockWeek'` styled as bodySmall with a slightly different color (e.g., primary color) to distinguish it from the exercise name.
  </action>
  <verify>Read the file and confirm: spacing after TM input is reduced, "Supplemental Work" label exists above supplemental data, cycle position appears in header when in block mode.</verify>
  <done>Calculator has tighter TM spacing, "Supplemental Work" label on supplemental section, and cycle position indicator in header when in block mode.</done>
</task>

</tasks>

<verification>
- Completed blocks in block overview show labeled TM grid (Squat/Bench/Deadlift/OHP) with "Training Max" header
- TM card has more vertical breathing room
- Calculator TM section has less bottom padding
- Calculator supplemental section has "Supplemental Work" label
- Calculator header shows cycle position (e.g., "Leader 1 - Week 2") in block mode
- No layout overflow or broken widgets
</verification>

<success_criteria>
All four UI improvements implemented: readable completed block TMs, expanded TM card padding, tighter calculator spacing with supplemental label, and cycle position display in calculator header.
</success_criteria>

<output>
After completion, create `.planning/quick/007-531-ui-fixes-block-progress-calculator/007-SUMMARY.md`
</output>
