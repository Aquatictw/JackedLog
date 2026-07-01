# JackedLog - Agent Context

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

Before broad code search, use `.planning/CONTEXT.md` for product language and current status to choose starting files.

## Server deploys (agents may run these)

The self-hosted server (`server/`) deploys via GHCR + Watchtower: push to `main`
→ GitHub Actions builds the image → Watchtower pulls it. Agent-friendly scripts
in `scripts/` automate the loop:

- `./scripts/prod-deploy` — push main, wait for the image build, trigger the
  container update, verify the new commit is live. Requires a clean worktree.
- `./scripts/prod-status` — health, running commit, pending updates.
- `./scripts/prod-logs [-f] [lines]` / `./scripts/prod-restart` — need SSH.

Config lives in `scripts/prod.env` (copy from `scripts/prod.env.example`).
**`prod.env` is gitignored and must never be committed — this repo is public.**
Never hardcode the server URL, API key, or SSH host anywhere tracked by git.

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
