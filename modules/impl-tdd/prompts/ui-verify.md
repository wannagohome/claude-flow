# Stage: ui-verify (Round {ROUND}/{MAX_ROUNDS})

Compare **actual app screenshots** captured during E2E tests against design specifications to verify UI correctness.

## Core Principles

- Judge based on the **actual rendered screen**, not the code.
- If no screenshot exists for a screen, record it as "unable to verify" (not a finding).
- **All severity levels of discrepancies are recorded as findings and must be fixed** (Critical, Warning, Minor).

## Inputs

1. **E2E screenshots**: E2E artifacts directory (platform-specific subdirectories)
2. **Design specifications**: Design references from spec documents or design tool
3. **Spec documents**: `{BASE_DIR}/spec/` (expected screen behavior reference)
4. **View component code**: Locate View files based on the screen list in the spec

## Verification Procedure

### 1. Collect Screenshots

Find screenshots related to this feature in the E2E artifacts directory.
Match feature/screen names from file names or paths.

If none exist, run the E2E tests with screenshot capture enabled:
```bash
cd {PROJECT_ROOT}
{E2E_SCREENSHOT_COMMAND}
```

If screenshots still do not exist, record in `screens_skipped` (not findings) and skip that screen.

### 2. Retrieve Design Specifications

For each screen, retrieve the design specification:

1. **Check spec documents for design references**: Search `{BASE_DIR}/spec/` for design node IDs, URLs, or file references
2. **Use design tools** (if available): Retrieve layout structure, tokens, spacing, colors from the design tool
3. **If no design reference exists**: Verify against the spec document's UI description only. Record as "spec-based verification" (not "unable to verify").

### 3. Screen-by-Screen Comparison

Compare each screenshot against its design reference:

#### Check Items
- [ ] **Layout structure**: Element placement order, alignment direction
- [ ] **Colors**: Background, text, icon colors (per theme system)
- [ ] **Typography**: Font size, weight (per typography spec)
- [ ] **Spacing**: Element spacing (only flag differences >= 8px)
- [ ] **State-specific UI**: Loading, empty, error states (if those screenshots exist)

#### Severity Criteria
| Severity | Criteria | Action |
|----------|----------|--------|
| Critical | Layout structure differs, major color mismatch, missing elements | Must fix |
| Warning | Spacing difference >= 8px, font weight/color tone mismatch | Fix |
| Minor | Difference <= 4px, reasonable design interpretation variance | Fix |

### 4. Fix Discrepancies

When discrepancies are found (any severity):
1. Modify the corresponding View component code
2. Run compile and lint checks
3. **Run the project's E2E update command** to refresh the JS bundle in the E2E binary (skipping this means fixes won't appear in E2E tests)
4. git commit

## Result

```json
{
  "status": "complete",
  "findings": <unfixed discrepancy count>,
  "by_severity": {
    "critical": <Critical count>,
    "warning": <Warning count>,
    "minor": <Minor count>
  },
  "fixed": <fixed count>,
  "screens_verified": <verified screen count>,
  "screens_skipped": <skipped due to no screenshot>,
  "details": [
    {
      "screen": "screen name",
      "screenshot": "file path",
      "severity": "critical|warning|minor",
      "description": "layout discrepancy description",
      "fixed": true
    }
  ],
  "summary": "Round {ROUND}: N screens verified, Critical C / Warning W / Minor M found, F fixed"
}
```

Write to `{RESULT_FILE}`.

**All severity levels must be fixed. `findings` is the unfixed count and must reach 0 to advance to the next stage.**
