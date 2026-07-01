# Issue tracker: Local Markdown (.planning/)

Issues and PRDs for this repo live as markdown files under `.planning/`.

## Conventions

- One feature per directory: `.planning/issues/<feature-slug>/`
- The PRD is `.planning/issues/<feature-slug>/PRD.md`
- Implementation issues are `.planning/issues/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

> Note: write only under `.planning/issues/` (and domain docs under `.planning/CONTEXT.md` / `.planning/docs/adr/`). Leave any other `.planning/` subfolders alone; other tools may own them.

## When a skill says "publish to the issue tracker"

Create a new file under `.planning/issues/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.
