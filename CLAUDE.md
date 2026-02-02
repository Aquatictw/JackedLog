# JackedLog - Claude Code Context

## CRITICAL RULES - READ FIRST

### DO NOT run any Flutter commands, ask user to run `flutter analyze` or manually test
### Always do manual migration
### If database version has been changed, and previous exported data from app can't be reimported, affirm me.

## Core Development Philosophy

### KISS (Keep It Simple, Stupid)

Simplicity should be a key goal in design. Choose straightforward solutions over complex ones whenever possible. Simple solutions are easier to understand, maintain, and debug.

### YAGNI (You Aren't Gonna Need It)

Avoid building functionality on speculation. Implement features only when they are needed, not when you anticipate they might be useful in the future.

### Design Principles

- **Open/Closed Principle**: Software entities should be open for extension but closed for modification.
- **Single Responsibility**: Each function, class, and module should have one clear purpose.
- **Fail Fast**: Check for potential errors early and raise exceptions immediately when issues occur.

## Code Search & Analysis Tools
### Primary Tool: ripgrep (rg)
Use `rg` (ripgrep) as your **PRIMARY and FIRST** tool for:
- ANY code search or pattern matching
- Finding function/class definitions
- Locating method calls or usage patterns
- Refactoring preparation
- Code structure analysis
- Fast, repository-wide searches using regex or literals

### Secondary Tool: grep
Use `grep` **ONLY** when:
- `rg` is not available
- Searching plain text, comments, or documentation
- Searching non-code files (markdown, configs, etc.)
- `rg` explicitly fails or is not applicable

**NEVER** use `grep` for searches without trying `rg` first.

## Token Efficiency

### Optimize Responses By
- **Focused Context**: Only include relevant code sections
- **Avoid Repetition**: Don't restate what I've already confirmed
- **Summarize When Asked**: Always respond in a very concise and direct manner, providing only relevant information
- Avoid **repeated or broad search commands** that may waste tokens

### Ask Before
- **Large File Changes**: "Should I show the entire file or just the diff?"
- **Multiple Approaches**: "Would you like me to explain alternatives or just go with the best option?"
- **Deep Dives**: "Do you need detailed explanation or just the solution?"

## Git Conventions

**Commit prefixes** (required):
- `fix:` — bug fixes
- `feat:` — new features
- `docs:` — documentation changes

## Prohibited Actions

❌ **Never**:
- Run Flutter commands without explicit permission
- Modify database schema without impact analysis
- Suggest complex solutions when simple ones exist
- Add dependencies without discussing alternatives
- Generate large amounts of boilerplate without asking first
- Use commit messages without fix:/feat:/docs: prefix

✅ **Always**:
- Consider backward compatibility
- Prefer Flutter/Dart built-ins over third-party packages when reasonable
- Think about edge cases and error scenarios
- Validate assumptions before implementing

## Project Overview

JackedLog is a Flutter/Dart fitness tracking mobile app (cross-platform: Android, iOS, Linux, macOS, Windows).

For detailed codebase documentation, see `.planning/codebase/`.

---

*Last updated: 2026-02-02*
