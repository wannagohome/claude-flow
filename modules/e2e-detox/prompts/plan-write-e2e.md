# Stage: plan-write-e2e

Convert `user-flows.json` into a human-readable E2E test plan document.

## Input

- **Feature**: {FEATURE}
- **User flows**: `{BASE_DIR}/test-plan/e2e/user-flows.json`
- **Traceability matrix** (if exists): `{BASE_DIR}/test-plan/e2e/scenario-traceability-matrix.json`
- **Spec documents**: `{BASE_DIR}/spec/` — Read all files
- **PRD**: {PRD_URL}
- **Figma**: {FIGMA_URL}

Read all input files first.

## Output

Create `{BASE_DIR}/test-plan/e2e/test-plan-e2e.md`.

---

## Document Structure

### 1. Overview

- Feature name and document purpose
- Test scope (in-scope / out-of-scope)
- E2E test framework: Detox (iOS/Android E2E testing)
- Test environment requirements

### 2. Scenario Coverage Matrix

Map requirements to scenarios in a table:

```markdown
| Requirement ID | Description | Covering Scenarios | Priority |
|---------------|-------------|-------------------|----------|
| REQ-001       | Feature X   | S-001, S-004      | high     |
| REQ-002       | Feature Y   | S-001             | high     |
```

- Use `scenario-traceability-matrix.json` data if available
- Mark rows with no covering scenarios as `**[GAP]**`

### 3. Test Account Requirements

Define account types needed for scenario execution:

```markdown
| Account Role     | Description               | Scenarios  |
|-----------------|---------------------------|------------|
| New user        | Just registered, no data   | S-005      |
| Regular user    | Has existing data          | S-001~004  |
| Expired session | Simulated token expiry     | S-008      |
```

### 4. Setup Helper List

Define helpers to achieve each precondition:

```markdown
| Helper Name          | Purpose                        | Used By    |
|---------------------|--------------------------------|------------|
| ensureWelcomeScreen | Logout then navigate to welcome | S-005      |
| ensureHomeScreen    | Login and navigate to home      | S-001~004  |
| ensureEmptyState    | Ensure no existing data         | S-006      |
```

> Use the project's E2E framework hooks (e.g., `beforeEach`) to invoke these helpers.

If scenarios involve WebView or hybrid content, define additional helpers for WebView interaction as needed by the project's E2E framework.

### 5. Per-Scenario Detail Spec

For each scenario, write the following format:

```markdown
---

## S-001: Happy Path - Core Feature Completion

**Type**: happy_path
**Priority**: high
**Covers Requirements**: REQ-001, REQ-002, REQ-003

### Precondition

- Helper: `ensureHomeScreen(account: 'general')`
- State: Logged in as regular user, home screen displayed

### Test Steps

| # | Action | testID / Selector | Expected Result |
|---|--------|-------------------|-----------------|
| 1 | Tap '+' button at bottom of home | `testID="fab-add"` | Creation form appears |
| 2 | Fill in required field | `testID="input-name"` | Field shows entered value |
| 3 | Tap submit button | `testID="submit-button"` | Loading indicator, then success |
| 4 | Verify result in list | `testID="item-list"` | New item appears in list |

### Verification Points

1. **Success feedback**: `testID="toast-success"` element shows "Saved" text
2. **Screen navigation**: Home screen `testID="home-screen"` is visible
3. **Data reflected**: Item list `testID="item-list"` contains the new entry

### Implementation Reference

- Test file: `e2e/flows/{feature}/S-001-description.e2e.ts`
```

### 6. Execution Order and Parallelization Strategy

```markdown
## Execution Groups

**Group A (Independent, parallel)**
- S-001: Happy path - core feature
- S-005: Empty state navigation

**Group B (Sequential dependencies)**
- S-006 -> S-007: Create then edit flow

**Group C (Special environment, isolated)**
- S-008: Session expiry simulation
- S-009: Network offline
```

### 7. Open Items and Assumptions

- Items that cannot be automated (require manual testing)
- Test data dependencies
- Platform-specific differences (iOS vs Android)

---

## Writing Rules

1. **testID references**: Use testIDs from spec or Figma. If not defined, mark as `[testID undefined - add during implementation]`.
2. **E2E framework**: Detox. All scenarios as `*.e2e.ts` files.
3. **Implementation file path**: Include for every scenario so implementers can reference it.
4. **Steps must be concrete**: Each step should be specific enough to translate directly into test code. Use the project's E2E testing framework patterns.
5. **Verification must be specific**: Every verification point must reference a specific UI element and expected content.

## Result

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": ["{BASE_DIR}/test-plan/e2e/test-plan-e2e.md"],
  "summary": "N scenarios included in E2E test plan, coverage matrix included"
}
```

Write to `{RESULT_FILE}`.
