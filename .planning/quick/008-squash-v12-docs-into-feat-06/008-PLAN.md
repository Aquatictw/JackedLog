---
phase: quick-008
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: []
autonomous: true

must_haves:
  truths:
    - "4 docs commits (e079ecf6, 96c240cd, 587c6f3c, 27dcb0cb) no longer exist as separate commits"
    - "feat: 06 commit contains all changes from the 4 docs commits"
    - "All commits after feat: 06 (07, 08, quick-005, 09, quick-007) still exist with correct content"
    - "Working tree is clean (stashed changes restored)"
  artifacts: []
  key_links: []
---

<objective>
Squash 4 docs: commits into the feat: 06 commit using non-interactive git rebase to comply with the ONE COMMIT PER PHASE convention.

Purpose: Clean up git history -- the 4 docs commits (research, requirements, roadmap, context) were intermediate planning work for phase 06 and should be part of the feat: 06 commit.
Output: Rewritten git history with 6 fewer commits in the range (10 commits become 6).
</objective>

<execution_context>
@/home/aquatic/.claude/get-shit-done/workflows/execute-plan.md
@/home/aquatic/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Git history (beb8c2f0..HEAD):
```
61a602cf feat: quick-007 531 UI fixes block progress and calculator   <-- HEAD
ab1cf4f4 feat: 09 block completion summary and history
d3eff649 feat: quick-005 531 UI compact TM editable phase labels
7d726fd7 feat: 08 calculator enhancement
39cfdcd6 feat: 07 block management
57054a66 feat: 06 data foundation for 5/3/1 block programming         <-- target: absorb docs into this
27dcb0cb docs: create milestone v1.2 roadmap (4 phases)               <-- fixup into 06
587c6f3c docs: define milestone v1.2 requirements                     <-- fixup into 06
96c240cd docs: complete v1.2 5/3/1 Forever block programming research <-- fixup into 06
e079ecf6 docs: start milestone v1.2 5/3/1 Forever Block Programming   <-- fixup into 06
beb8c2f0 feat: quick-004 fix notes stale cache after edit             <-- rebase base
```

Uncommitted changes that must be preserved:
- M lib/notes/notes_page.dart
- M lib/widgets/training_max_editor.dart
- ?? .planning/quick/007-531-ui-fixes-block-progress-calculator/007-PLAN.md
- ?? workoutplan.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Stash uncommitted changes and perform non-interactive rebase</name>
  <files>N/A - git history manipulation only</files>
  <action>
Step 1: Stash ALL uncommitted changes (tracked modified + untracked):
```bash
git stash push --include-untracked -m "quick-008: stash before rebase"
```

Step 2: Create a sed script that will be used as GIT_SEQUENCE_EDITOR to rewrite the rebase todo list.
The rebase onto beb8c2f0 will produce a todo list like:
```
pick e079ecf6 docs: start milestone v1.2 ...
pick 96c240cd docs: complete v1.2 ...
pick 587c6f3c docs: define milestone v1.2 ...
pick 27dcb0cb docs: create milestone v1.2 roadmap ...
pick 57054a66 feat: 06 data foundation ...
pick 39cfdcd6 feat: 07 ...
pick 7d726fd7 feat: 08 ...
pick d3eff649 feat: quick-005 ...
pick ab1cf4f4 feat: 09 ...
pick 61a602cf feat: quick-007 ...
```

The sed script must reorder so feat:06 comes first, then the 4 docs as fixup, then the rest:
```
pick 57054a66 feat: 06 data foundation ...
fixup e079ecf6 docs: start milestone v1.2 ...
fixup 96c240cd docs: complete v1.2 ...
fixup 587c6f3c docs: define milestone v1.2 ...
fixup 27dcb0cb docs: create milestone v1.2 roadmap ...
pick 39cfdcd6 feat: 07 ...
pick 7d726fd7 feat: 08 ...
pick d3eff649 feat: quick-005 ...
pick ab1cf4f4 feat: 09 ...
pick 61a602cf feat: quick-007 ...
```

Use GIT_SEQUENCE_EDITOR with a script file (not inline sed -- too fragile with short hashes).
Create a temporary script at /tmp/rebase-editor.sh that:
1. Reads the todo file
2. Removes the 4 docs lines and the feat:06 line from their original positions
3. Inserts feat:06 as "pick" at the top, followed by the 4 docs lines changed to "fixup"
4. Leaves all other "pick" lines in their original order after

```bash
cat > /tmp/rebase-editor.sh << 'SCRIPT'
#!/bin/bash
TODO="$1"

# Extract lines
FEAT06=$(grep "57054a66" "$TODO" | head -1)
DOC1=$(grep "e079ecf6" "$TODO" | head -1)
DOC2=$(grep "96c240cd" "$TODO" | head -1)
DOC3=$(grep "587c6f3c" "$TODO" | head -1)
DOC4=$(grep "27dcb0cb" "$TODO" | head -1)

# Get remaining lines (everything that is NOT one of the 5 lines above, preserving order)
REMAINING=$(grep -v -e "57054a66" -e "e079ecf6" -e "96c240cd" -e "587c6f3c" -e "27dcb0cb" "$TODO")

# Build new todo:
# 1. feat:06 as pick (already is pick)
# 2. 4 docs as fixup (change "pick" to "fixup")
# 3. remaining picks in original order
{
  echo "$FEAT06"
  echo "$DOC1" | sed 's/^pick/fixup/'
  echo "$DOC2" | sed 's/^pick/fixup/'
  echo "$DOC3" | sed 's/^pick/fixup/'
  echo "$DOC4" | sed 's/^pick/fixup/'
  echo "$REMAINING"
} > "$TODO"
SCRIPT
chmod +x /tmp/rebase-editor.sh
```

Step 3: Run the rebase:
```bash
GIT_SEQUENCE_EDITOR="/tmp/rebase-editor.sh" git rebase -i beb8c2f0
```

Step 4: Verify the rebase succeeded:
- `git log --oneline beb8c2f0..HEAD` should show exactly 6 commits (feat:06, 07, 08, quick-005, 09, quick-007)
- No docs: commits should appear
- `git status` should show clean working tree (no conflicts)

Step 5: Pop the stash:
```bash
git stash pop
```

Step 6: Final verification:
- `git log --oneline beb8c2f0..HEAD` shows 6 commits, no docs: commits
- `git stash list` shows no remaining stash from this operation
- `git status` shows the same uncommitted changes as before (M notes_page.dart, M training_max_editor.dart, untracked files)
  </action>
  <verify>
Run:
1. `git log --oneline beb8c2f0^..HEAD` -- must show exactly 7 commits (beb8c2f0 + 6 rebased), no "docs:" commits visible
2. `git diff --stat HEAD~1..HEAD` on the new feat:06 commit -- should include .planning/ docs files
3. `git status` -- should show same uncommitted changes as before the operation
  </verify>
  <done>
- Git history from beb8c2f0 to HEAD contains exactly 6 commits (feat:06, feat:07, feat:08, feat:quick-005, feat:09, feat:quick-007)
- Zero "docs:" commits exist in that range
- The feat:06 commit contains all the .planning/ changes from the 4 former docs commits
- Uncommitted working tree changes are preserved (stash popped successfully)
  </done>
</task>

</tasks>

<verification>
1. `git log --oneline beb8c2f0^..HEAD` shows exactly 7 lines (base + 6 commits), none starting with "docs:"
2. `git show --stat <new-feat-06-hash>` includes .planning/ files from the docs commits
3. `git status` matches pre-rebase state (modified and untracked files present)
4. No rebase in progress (`ls .git/rebase-merge` fails)
</verification>

<success_criteria>
- 4 docs commits successfully squashed into feat: 06
- All 5 subsequent commits (07, 08, quick-005, 09, quick-007) intact with correct messages
- Working tree restored to pre-operation state
- No rebase artifacts or conflicts
</success_criteria>

<output>
After completion, create `.planning/quick/008-squash-v12-docs-into-feat-06/008-SUMMARY.md`
</output>
