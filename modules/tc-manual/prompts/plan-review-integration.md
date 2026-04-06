# Stage: plan-review-integration (Round {ROUND}/{MAX_ROUNDS})

You are an **external auditor** seeing this integration test plan for the first time.
You have no relationship with the person who created this document.

## Core Principles

- **Do NOT give the benefit of the doubt ("they probably left it out intentionally").**
- If it is not in the document, it is missing.
- Record "no issues found" with evidence too.

## Input

1. **Integration test plan**: `{BASE_DIR}/test-plan/integration/test-plan-integration.md` — must read
2. **Spec documents**: `{BASE_DIR}/spec/` — read overview first, then specific files as needed

## Validation Checklist

Validate **each item in order**. Do not skip any.

### 1. Requirement Coverage

- [ ] Does every REQ-ID from the spec have a corresponding section in the test plan?
      List all spec REQ-IDs and note any missing
- [ ] Does each requirement have at least 1 happy path test case?
- [ ] Does each requirement have at least 1 boundary value test case (where applicable)?
- [ ] Does each requirement have at least 1 error condition test case?

### 2. Test Case Specificity

- [ ] Is each TC's expected result **specific enough to convert to an assertion**?
      Look for vague phrases like "succeeds", "works correctly", "handles properly"
      Good: "Returns `Result[]` array with `status: 'active'`"
      Bad: "Returns correct result"
- [ ] Do error scenario TCs specify **exception types**?
      "Error occurs" is insufficient — need `NetworkError`, `ValidationError`, etc.
- [ ] Are input values **concrete** (not just "valid input" or "invalid input")?
      Good: `quantity=0`, `email=""`
      Bad: "invalid value"

### 3. Test Plan Completeness

- [ ] Are there any **redundant test cases** that test the same condition?
      Flag duplicates for removal
- [ ] Are **implicit parameters** covered?
      Always check for:
  - Network state (connected, offline, timeout)
  - Auth/token state (valid, expired, missing)
  - Concurrency (duplicate requests, rapid clicks)
- [ ] Does the test boundary clearly define what is under test vs. mocked?

### 4. TDD Guide Accuracy

- [ ] Are component names verifiable from the spec?
- [ ] Are file paths consistent with the project structure?
- [ ] Does the test skeleton follow the project's testing conventions?

## Finding Format

```markdown
## Finding F-{NNN}
- **Type**: coverage | specificity | completeness | tdd-accuracy
- **Severity**: critical | major | minor
- **Location**: [TC-ID or section name]
- **Evidence**: "REQ-003 has no error condition test case"
- **Fix**: [specific TC to add or modification]
```

## Fix Procedure

1. Complete all checklist items to build findings list
2. Fix critical/major findings directly in `test-plan-integration.md`
3. Fix minor findings when possible
4. Leave unfixable items in findings

## Result

Write to `{RESULT_FILE}` after validation:

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "remaining": [
    {"id": "F-001", "severity": "major", "description": "..."}
  ],
  "summary": "Round {ROUND}: N found, M fixed"
}
```

**CRITICAL**: `findings` and `fixed` must be **number** type. No strings.

**If findings is 0, the pipeline advances to the next stage.**
