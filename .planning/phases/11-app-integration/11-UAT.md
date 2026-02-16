---
status: testing
phase: 11-app-integration
source: [11-01-SUMMARY.md, 11-02-SUMMARY.md]
started: 2026-02-15T12:00:00Z
updated: 2026-02-15T12:00:00Z
---

## Current Test

number: 1
name: Navigate to Backup Server settings
expected: |
  In Settings page, a "Backup Server" entry with a cloud upload icon appears after "Data management". Tapping it opens the Server Settings page.
awaiting: user response

## Tests

### 1. Navigate to Backup Server settings
expected: In Settings page, a "Backup Server" entry with a cloud upload icon appears after "Data management". Tapping it opens the Server Settings page.
result: [pending]

### 2. Configure Server URL
expected: Server URL field shows "https://myserver.com" hint text. Entering a URL and leaving the field saves it. Trailing slashes are stripped automatically.
result: [pending]

### 3. Configure API Key with masked toggle
expected: API Key field is masked (dots) by default. Tapping the eye icon reveals the key text. Tapping again re-masks it. Value persists after leaving and returning to the page.
result: [pending]

### 4. Test Connection
expected: "Test Connection" button is disabled when URL or API key is empty. With both filled, tapping it shows a success toast (if server is reachable with valid key) or a descriptive error message (if unreachable or wrong key).
result: [pending]

### 5. Push Backup to Server
expected: On the backup settings page, a "Push to Server" section appears when server URL is configured. Tapping the push button shows a progress indicator during upload, then completes.
result: [pending]

### 6. Push Status Display
expected: Before any push: shows "Never pushed" with cloud-off icon. After successful push: shows "Last pushed: X ago" with checkmark icon. After failed push: shows "Last push failed" in red with error icon.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0

## Gaps

[none yet]
