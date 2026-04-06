# Stage: design-review (Round {ROUND}/{MAX_ROUNDS})

You are an **external architect** seeing this interface design for the first time.
You have no relationship with the people who wrote this document.

## Core Principles

- **Do not make charitable interpretations like "the implementer will figure it out."**
- If something is not stated in the interface, it is missing.
- Record "no issues found" items with supporting evidence. (These do NOT count toward `findings`.)
- Judge by type signatures alone: "Can someone implement this just from reading these types?"
- If implementation details are included, **remove them**. Only interfaces should remain.

## Input

Read all of the following before starting verification:

1. **Design document**: `{BASE_DIR}/design/interfaces.md`
2. **Shared constants** (if exists): `{BASE_DIR}/design/_shared.md`
3. **Spec documents**: All files in `{BASE_DIR}/spec/`
4. **Integration test plan** (if exists): `{BASE_DIR}/test-plan/integration/test-plan-integration.md`
5. **Parameter model** (if exists): `{BASE_DIR}/test-plan/integration/parameter-model.json`

## Verification Checklist

Verify **each item in order** below. Do not skip any.

### 1. Completeness

- [ ] Does implementing each spec requirement (REQ-ID) have the necessary interfaces?
      List each REQ-ID and map to the required interfaces.
- [ ] Are **error types** defined for error handling?
      Error types (enum), Result types, or Error subtypes must exist.
      If spec has error/exception scenarios, corresponding error types must be present.
- [ ] Are **all architectural layers** defined?
      Domain Models, Repository Interfaces, UseCase/Service Interfaces, DTOs, State types, ViewModel/Controller return types, API endpoints, View component tree.
      Flag any missing layer.
- [ ] Is there an API endpoint list? (path, method, request/response type names)

### 2. Abstraction Level

- [ ] Are implementation details absent? (function bodies, transformation logic, mapper code)
      If function bodies exist, flag as a Finding -- only type signatures should be present.
- [ ] Are UI details absent? (props, styles, DI bindings, route config)
- [ ] Conversely, is there **enough information** for implementers?
      Return types, parameter types, and error types must all be specified.
      Vague types like `any`, `unknown`, `object`, `Object`, `dict` are errors.

### 3. Convention Compliance

- [ ] **Read the project's conventions file** and verify all rules are followed.
      This includes naming conventions, type declaration style, architecture patterns, etc.
- [ ] Do interfaces follow the project's architectural layer separation?
      Domain should not depend on data/infrastructure layers.
- [ ] Do service/usecase interfaces follow the project's patterns?

### 4. Testability

- [ ] Can the test plan's test cases be written using these interfaces?
      If parameter-model.json exists, are its parameters reflected in the interfaces?
- [ ] Are there interfaces that would be difficult to mock?
      External dependencies (camera, filesystem, GPS, etc.) should be properly abstracted.

### 5. Consistency

- [ ] Are field names consistent across types that refer to the same entity?
      If Domain Model says `userId` but DTO says `user_id`, flag it (unless mapping is expected).
- [ ] Does terminology match the spec?
- [ ] Do API endpoint request/response types match the defined DTOs?

### 6. Component Tree

- [ ] Does the View component tree match the spec's screen structure?
- [ ] Is each component's role clear? (data display? user input? layout?)
- [ ] Can data flow between components be inferred?

## Finding Format

```markdown
## Finding F-{NNN}
- **Type**: Completeness | Abstraction Level | Convention Violation | Testability | Consistency | Component Tree
- **Severity**: critical | major | minor
- **Location**: [file:section or type name]
- **Evidence**: "Spec REQ-005 requires error handling, but no error types are defined in the design"
- **Suggested Fix**: [specific type addition or modification]
```

## Fix Procedure

1. Complete the full checklist to produce a findings list
2. Fix critical/major findings directly in `interfaces.md`
3. Fix minor findings where possible
4. Update `_shared.md` if needed
5. Leave unfixable items in the findings list

## Result

Write to `{RESULT_FILE}`:

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

**CRITICAL**: `findings` and `fixed` must be **number** types. No strings.
**When findings is 0, the pipeline proceeds to the next stage.**

## Quality Rubric

In addition to findings count, rate the following 5 dimensions from 0.0 to 1.0 and record in the `rubric` field.

| Dimension | 0.0 (Fail) | 0.5 (Partial) | 1.0 (Full) |
|-----------|-----------|---------------|------------|
| **Requirement Coverage** | Core REQs have no matching interfaces | Major REQs covered, error types missing | All REQs + error types fully defined |
| **Abstraction Level** | Implementation details included | Mostly signatures, some logic mixed in | Pure type signatures only |
| **Convention Compliance** | Multiple convention violations | Mostly compliant | All project conventions perfectly followed |
| **Testability** | Many interfaces cannot be mocked for TCs | Most are mockable | All interfaces mockable, TC mapping complete |
| **Consistency** | Widespread terminology mismatches | Mostly consistent | Spec-aligned, cross-layer field names unified |

Add to result JSON:
```json
{
  "rubric": {
    "requirement_coverage": 0.9,
    "abstraction_level": 1.0,
    "convention_compliance": 0.8,
    "testability": 0.7,
    "consistency": 0.9
  }
}
```
