# Stage: scenario-extract

Extract E2E user flow scenarios from the spec documents.

## Input

- **Feature**: {FEATURE}
- **Spec documents**: `{BASE_DIR}/spec/` — Read all files
- **PRD**: {PRD_URL}
- **Figma**: {FIGMA_URL}

## Procedure

### 1. Read All Spec Files

Read all `.md` files in `{BASE_DIR}/spec/`.
For each file, identify:
- Requirement IDs (REQ-XXX or similar format)
- Business policies and rules
- Screen flows and user actions
- Error/exception cases
- Boundary conditions
- UI states (loading, error, empty state)

### 2. Identify User Flows

Identify scenarios in the following categories:

**Happy Path**: Normal user flows
- Normal completion flow for each core feature
- Full flow through multi-step workflows

**Error Recovery**: Error recovery flows
- Retry after network failure
- Re-login after session expiry
- Correction after invalid input
- Alternative path after server error

**Edge Cases**: Boundary/special cases
- Navigation with empty list
- Maximum item count reached
- First-time user onboarding
- Exploring with no data

### 3. Generate Output

Create `{BASE_DIR}/test-plan/e2e/user-flows.json`:

```json
{
  "feature": "{FEATURE}",
  "generated_at": "<ISO-8601 timestamp>",
  "scenarios": [
    {
      "id": "S-001",
      "name": "Happy Path - Scenario name",
      "type": "happy_path",
      "precondition": "Logged in, on home screen",
      "depends_on": [],
      "flow": [
        "Tap the 'Add' button on the home screen",
        "Verify the creation form screen appears",
        "Fill in required fields",
        "Tap the submit button",
        "Verify success confirmation"
      ],
      "verifications": [
        "Success toast message is displayed",
        "Automatically navigates to home screen",
        "New item appears in the list"
      ],
      "covers_requirements": ["REQ-001", "REQ-003"],
      "priority": "high"
    },
    {
      "id": "S-002",
      "name": "Error Recovery - Retry after network failure",
      "type": "error_recovery",
      "precondition": "Logged in, network offline",
      "depends_on": [],
      "flow": [
        "Attempt to submit data",
        "Verify network error message",
        "Reconnect network",
        "Tap retry button"
      ],
      "verifications": [
        "Error message is clearly displayed",
        "Retry completes successfully"
      ],
      "covers_requirements": ["REQ-010"],
      "priority": "medium"
    }
  ]
}
```

**Required scenarios:**
- Happy path for every core feature (at least 1 per feature)
- Network failure recovery scenario (at least 1)
- Session expiry recovery scenario (at least 1)
- Empty state / initial state scenario (where applicable)
- Every requirement must be covered by at least one scenario

**Scenario ID rules:**
- Start from S-001, sequential
- Order: happy_path first, then error_recovery, then edge_case

**Priority criteria:**
- `high`: Core user journey, covers critical requirements
- `medium`: Error recovery, secondary features
- `low`: Edge cases, boundary values

**Scenario dependency rules:**
- `depends_on`: Array of scenario IDs this scenario depends on
  e.g., edit scenario depends on create scenario: `"depends_on": ["S-001"]`
- Empty array `[]` if no dependencies
- Dependency info is used to determine E2E execution order

**Flow writing rules:**
- Each step should describe a specific UI action ("Tap the '+' button at the bottom" instead of "navigate")
- Include screen arrival verification after transitions
- Include loading state checks for intermediate states

### 4. Record Result

Write to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": ["{BASE_DIR}/test-plan/e2e/user-flows.json"],
  "summary": "N scenarios extracted (happy_path: X, error_recovery: Y, edge_case: Z), REQ coverage: M/M"
}
```
