# Stage: plan-write-integration

Convert PICT-generated test combinations and parameter model into an integration test plan document.

## Input

Read all of the following files before starting:

1. **PICT combinations**: `{BASE_DIR}/test-plan/integration/test-combinations.json`
2. **Parameter model**: `{BASE_DIR}/test-plan/integration/parameter-model.json`
3. **Traceability matrix**: `{BASE_DIR}/test-plan/integration/traceability-matrix.json`
4. **Spec documents**: `{BASE_DIR}/spec/` — Read all files

## Test Boundary

Define the integration test boundary based on the project's architecture. Identify:

- **Under test**: The core logic layers (e.g., use cases, domain models, repositories, stores)
- **Mocked**: External dependencies (e.g., API clients, external SDKs, third-party services)

Follow the project's testing conventions for mock setup and test structure.

## Output

Create `{BASE_DIR}/test-plan/integration/test-plan-integration.md`.

### File Structure

```markdown
# Integration Test Plan: {FEATURE}

> **Generated from**
> - Spec: `{BASE_DIR}/spec/`
> - Parameter model: `{BASE_DIR}/test-plan/integration/parameter-model.json`
> - PICT combinations: `{BASE_DIR}/test-plan/integration/test-combinations.json`
> - Generated: <ISO 8601 date>

## Test Scope

- **Under test**: [Identify from project architecture — e.g., UseCase -> Repository -> Store]
- **Mocked**: [External dependencies — e.g., API Client]
- **Test framework**: [Project's test framework from conventions]
- **Test description format**: [Project's test naming convention from conventions]

---

## REQ-{NNN}: {requirement description}

### Parameters

| Parameter | Type | Values | Risk |
|-----------|------|--------|------|
| ParamName | enum/range/boolean | val1, val2, ... | high/medium/low |

### Test Cases

| TC-ID | {param1} | {param2} | ... | Expected Behavior |
|-------|----------|----------|-----|-------------------|
| TC-001 | ValA | ValB | ... | Core logic returns X, state updated to Y |
| TC-002 | ValC | ValD | ... | Core logic throws ErrorType, state unchanged |

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
    it('When {action} then {expected behavior}', async () => {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

---
```

### Per-Requirement Rules

- Create one section for each REQ-ID in `parameter-model.json`.
- Map combination rows from `test-combinations.json` to TC rows in order.
- TC-ID format: `TC-{REQ number}-{combination sequence}` (e.g., `TC-001-01`)

### Expected Behavior Rules

Expected behaviors must satisfy all of the following:

- **Specific**: Instead of "succeeds", write "returns a `FoodItem` array"
- **Verifiable**: Must be convertible to an assertion
- **Layer-aware**: Specify state changes, return values, exception types
- **Error cases**: Specify the exact exception type (e.g., `NetworkError`, `ValidationError`)

### TDD Guide Rules

- Identify the component name and file path from the spec. If not specified, follow the project's naming convention.
- Mock targets should be external dependencies (API clients, SDKs), not internal interfaces.
- Follow the project's mock library and testing conventions as defined in the conventions file.
- Follow the project's test description format and naming convention.

## Traceability Matrix Reflection

Read `traceability-matrix.json` to verify which TCs cover which REQs.
If a REQ is missing from the matrix, add TCs for it and update the matrix.

## Completion Criteria

- [ ] All REQ-IDs have a corresponding section
- [ ] All PICT combination rows are converted to TCs
- [ ] Each TC's expected behavior is specific enough to write assertions
- [ ] Error scenario TCs specify exception types
- [ ] TDD guide includes actual component paths

Write the result to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": [
    "{BASE_DIR}/test-plan/integration/test-plan-integration.md"
  ],
  "summary": "N REQs, M TCs — integration test plan written"
}
```
