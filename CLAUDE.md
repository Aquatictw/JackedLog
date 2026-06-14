# JackedLog - Claude Code Context

## CRITICAL RULES - READ FIRST

### Always do manual migration
### If database version has been changed, and previous exported data from app can't be reimported, affirm me.

## Agent skills

### Issue tracker

Issues and PRDs live as local markdown under `.planning/issues/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles, each label string equals its name (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `.planning/CONTEXT.md` + `.planning/docs/adr/`. See `docs/agents/domain.md`.

### File routing

Before broad code search, read `.planning/FILE_MAP.md` and use the relevant feature slice to choose starting files. Use `.planning/CONTEXT.md` for product language and current status.
## Shell rules

This repo is usually used from PowerShell on Windows.

Prefer:
- `pwsh` / PowerShell 7 for interactive agent sessions.
- `rg --files` to list project files.
- `rg -n "pattern" .` to search text.
- `fd "name"` to find files by name.
- `Get-ChildItem -Force` for directory listings.
- `Get-ChildItem -Recurse -File` for recursive file listings.
- `Get-Content -Raw -LiteralPath "path"` to read a whole file.
- `Get-Content -LiteralPath "path" -TotalCount 200` to preview a file.
- `Set-Location -LiteralPath "path"` to navigate safely.
- `just <recipe>` for repeatable project commands.

Avoid Bash-only syntax in this repo's default shell:
- `ls -la`
- `cat <<EOF`
- `grep`
- `sed -n`
- `rm -rf`
- `/tmp/...`
- `export FOO=bar`
- Unix-style path assumptions.

For file edits, prefer agent patch/edit tools over shell heredocs.


---

*Last updated: 2026-02-02*
