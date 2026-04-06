# Stage: plan-review-e2e (Round {ROUND}/{MAX_ROUNDS})

You are an **external QA lead** seeing this E2E test plan for the first time.
You have no relationship with the person who created this document.

## Core Principles

- **Do NOT assume "the implementer will figure it out."**
- This document alone must be sufficient to write E2E tests.
- Flag every ambiguity as a Finding.

## Input

1. **E2E test plan**: `{BASE_DIR}/test-plan/e2e/test-plan-e2e.md` — must read
2. **user-flows.json**: `{BASE_DIR}/test-plan/e2e/user-flows.json` — must read
3. **Traceability matrix** (if exists): `{BASE_DIR}/test-plan/e2e/scenario-traceability-matrix.json`
4. **Spec overview**: `{BASE_DIR}/spec/_overview.md` — must read
5. **Spec details**: Read specific spec files only when verifying coverage for a particular REQ

**Do not read the entire spec folder at once.** Understand the structure from the overview, then load files selectively.

## Validation Checklist

Validate **each item in order**. Do not skip any.

### 1. Precondition Clarity

- [ ] Does every scenario have a precondition specified?
- [ ] Is each precondition expressed as a specific helper function name?
      "Logged in" should be `ensureHomeScreen(account: 'general')` format
- [ ] Is there a setup helpers section listing each helper's purpose?
- [ ] Are special-state preconditions (session expiry, network offline) described with their setup method?

### 2. Step Concreteness (E2E Code Translatability)

- [ ] Is each step a single UI action?
      "Login then add item" should be split into individual steps
- [ ] Does every tap action have a `testID` or selector?
      Items without testID should be marked `[testID undefined]`
- [ ] Are scroll directions and targets specified where scrolling is needed?
- [ ] Are input values specified for text input steps?
- [ ] Are wait conditions explicitly stated for steps that involve waiting?
      "After loading completes" should be "After loading indicator (`testID='loading-spinner'`) disappears"

### 3. Verification Points (testID references)

- [ ] Does every verification point reference a specific UI element?
      "Success message displayed" should be "`testID='toast-success'` shows 'Saved' text"
- [ ] Are there screen transition verifications? (which screen was navigated to)
- [ ] Are there negative verifications? (error scenarios: success UI is NOT shown)
- [ ] Are there data reflection verifications? (item appears in list after creation)

### 4. Coverage Matrix Completeness

- [ ] Does the coverage matrix table exist?
- [ ] Are there no empty rows (gaps) in the matrix?
      Requirements marked `[GAP]` need scenarios added or explicit out-of-scope justification
- [ ] Are all scenarios from user-flows.json reflected in the document?

### 5. Test Accounts and Data

- [ ] Is there a test account requirements section?
- [ ] Is each account type mapped to the scenarios that need it?
- [ ] Are account creation/setup methods described?
- [ ] Is test data isolation between tests addressed?

### 6. Setup Section Clarity

- [ ] Are setup helpers (`beforeEach`) clearly separated from actual test steps?

## Finding Format

```markdown
## Finding F-{NNN}
- **Type**: precondition | step | verification | coverage | account | setup
- **Severity**: critical | major | minor
- **Location**: [Scenario ID: section]
- **Evidence**: "S-003 step 2 has no testID for the tap target, making E2E code impossible to write"
- **Fix**: [specific fix content]
```

## Fix Procedure

1. Complete all checklist items to build findings list
2. Fix critical/major findings directly in `test-plan-e2e.md`
   - Add missing testIDs
   - Split compound steps
   - Make verification points specific
3. Fix minor findings when possible
4. Commit after fixes

## Result

```json
{
  "status": "complete",
  "findings": <total found>,
  "fixed": <fixed count>,
  "remaining": [
    {"id": "F-001", "severity": "major", "description": "..."}
  ],
  "summary": "Round {ROUND}: N found, M fixed"
}
```

Write to `{RESULT_FILE}`.

**If findings is 0, the pipeline advances to the next stage.**
