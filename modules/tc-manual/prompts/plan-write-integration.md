# Stage: plan-write-integration (Manual)

Write integration test plan directly from spec, without PICT combinatorial generation.

## Input

- **Spec**: `{BASE_DIR}/spec/` — Read all spec files

## Task

For each requirement in the spec:
1. Identify testable parameters and their values
2. Write test cases covering:
   - Happy path for each requirement
   - Boundary values
   - Error conditions
   - Important parameter combinations
3. Format as a structured test plan

## Test Boundary

Define the integration test boundary based on the project's architecture. Identify:

- **Under test**: The core logic layers (e.g., use cases, domain models, repositories, stores)
- **Mocked**: External dependencies (e.g., API clients, external SDKs, third-party services)

Follow the project's testing conventions for mock setup and test structure.

## Output

Write to `{BASE_DIR}/test-plan/integration/test-plan-integration.md`

### Document Structure

```markdown
# Integration Test Plan: {FEATURE}

> **Generated from**
> - Spec: `{BASE_DIR}/spec/`
> - Generated: <ISO 8601 date>

## Test Scope

- **Under test**: [Identify from project architecture]
- **Mocked**: [External dependencies]
- **Test framework**: [Project's test framework from conventions]
- **Test description format**: [Project's test naming convention]

---

## REQ-{NNN}: {requirement description}

### Parameters

| Parameter | Type | Values | Risk |
|-----------|------|--------|------|
| ParamName | enum/range/boolean | val1, val2, ... | high/medium/low |

### Test Cases

| TC ID | Description | Input | Expected Result | Covers |
|-------|-------------|-------|-----------------|--------|
| TC-001 | Happy path - normal input | param=value | Returns expected result, state updated | REQ-001 |
| TC-002 | Boundary - minimum value | param=min | Handles minimum correctly | REQ-001 |
| TC-003 | Error - invalid input | param=invalid | Throws ValidationError, state unchanged | REQ-001 |

### TDD Guide

**Target under test**: `{ComponentName}` (`path/to/component`)

**Mock setup**:
```
// Mock external dependency
// Follow the project's mock library and conventions
```

**Test skeleton**:
```
describe('{ComponentName}', () => {
  describe('Given {condition}', () => {
    it('When {action} then {expected}', async () => {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

---
```

### Test Case Writing Rules

- **TC-ID format**: `TC-{REQ number}-{sequence}` (e.g., `TC-001-01`)
- **Expected Result must be specific**: Instead of "succeeds", write "returns `Item[]` array with 3 elements"
- **Error cases must specify exception type**: e.g., `NetworkError`, `ValidationError`
- **Each requirement must have**:
  - At least 1 happy path TC
  - At least 1 boundary value TC (if applicable)
  - At least 1 error condition TC
- **Follow the project's testing conventions** for mock setup, test structure, and naming

## Completion Criteria

- [ ] All REQ-IDs from spec have corresponding test case sections
- [ ] Each requirement has happy path, boundary, and error test cases
- [ ] Expected results are specific enough to write assertions
- [ ] Error TCs specify exception types
- [ ] TDD guide includes component paths from spec
- [ ] No redundant or duplicate test cases

Write the result to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": ["{BASE_DIR}/test-plan/integration/test-plan-integration.md"],
  "summary": "N REQs, M TCs — integration test plan written"
}
```
