# Stage: scenario-review (Round {ROUND}/{MAX_ROUNDS})

You are an **external QA auditor** seeing this scenario list for the first time.
You have no relationship with the person who created these scenarios.

## Core Principles

- **Do NOT give the benefit of the doubt ("they probably left it out intentionally").**
- If it is not in the scenarios, it is missing.
- Validate each checklist item in order. Do not skip any.

## Input

1. **user-flows.json**: `{BASE_DIR}/test-plan/e2e/user-flows.json` — must read
2. **Spec overview**: `{BASE_DIR}/spec/_overview.md` — must read (for REQ-ID list)
3. **Spec details**: Read specific spec files only when verifying a particular REQ
4. **PRD** (if available): {PRD_URL}

**Do not read the entire spec folder at once.** Understand the structure from the overview, then load files selectively.

## Validation Checklist

### 1. Requirement Coverage

- [ ] Extract all requirement IDs from spec files
      List each REQ-ID with its covering scenario ID(s) next to it
- [ ] Are there any scenarios with empty `covers_requirements`?
- [ ] Are there any requirements not mapped to any scenario (gaps)?
      If gaps exist, record as Finding and add scenarios to fix

### 2. Happy Path Completeness

- [ ] Is there at least 1 happy_path scenario per core feature?
      Cross-reference with the spec's feature list
- [ ] Does each happy_path scenario include the full start-to-finish flow?
      Check for skipped intermediate steps
- [ ] Does each happy_path include success verification points?

### 3. Error Recovery Scenarios

- [ ] Is there a mid-operation network failure scenario?
      Not just "failure before API call" but "failure during operation"
- [ ] Is there a session expiry (auth token expired) scenario?
- [ ] Is there a server error (5xx) scenario?
- [ ] Do error scenarios include recovery to successful completion?
      Scenarios that only show the error and stop are incomplete

### 4. Edge Case Scenarios

- [ ] Is there an empty list navigation flow?
- [ ] Is there a max item count / limit reached scenario? (if spec defines limits)
- [ ] Is there a first-time user (no data) scenario?
- [ ] Are spec-defined boundary conditions reflected in scenarios?

### 5. Precondition Feasibility

- [ ] Are all preconditions actually achievable in a test environment?
      How would you create "specific item in cart" state?
- [ ] Are preconditions specific enough (not too broad or vague)?
      "Logged in" should specify "logged in with test account that has X state"
- [ ] Can each precondition be implemented as a setUp helper in the E2E framework?

### 6. Verification Specificity

- [ ] Is each verification more specific than just "X is displayed"?
      "Success message displayed" should be "Toast shows 'Record saved' text"
- [ ] Are there screen transition verifications? (which screen was navigated to)
- [ ] Are there data change verifications? (UI reflects the change, not just DB/store)
- [ ] Are there negative verifications for error scenarios? (success UI is NOT shown)

## Finding Format

```markdown
## Finding F-{NNN}
- **Type**: coverage | happy_path | error_recovery | edge_case | precondition | verification
- **Severity**: critical | major | minor
- **Location**: [scenario ID or entire file]
- **Evidence**: "REQ-XXX is defined in spec but no scenario covers it"
- **Fix**: [scenario to add or content to modify]
```

## Fix Procedure

1. Complete all checklist items to build findings list
2. Fix critical/major findings directly in `user-flows.json`
   - When adding scenarios, maintain the existing ID scheme (assign next number)
   - When modifying scenarios, preserve existing content and supplement
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

**If findings is 0, the pipeline advances to the next stage (coverage-check).**
