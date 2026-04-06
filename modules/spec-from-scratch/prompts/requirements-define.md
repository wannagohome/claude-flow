# Stage: requirements-define

Define functional and non-functional requirements for: {FEATURE}

## Input

1. **User description**: `{BASE_DIR}/spec/requirements-input.md`
2. **Research notes**: `{BASE_DIR}/spec/research-notes.md`

Read both files first.

## Task

Define structured requirements:
1. **Functional Requirements (FR)**: What the system must do
2. **Non-Functional Requirements (NFR)**: Performance, security, accessibility constraints
3. **Acceptance Criteria**: Specific, testable conditions for each FR
4. **Out of Scope**: Explicitly state what is NOT included

## Output

Write to `{BASE_DIR}/spec/requirements.md`:

```markdown
# Requirements: {FEATURE}

## Functional Requirements

### FR-001: [Title]
- **Description**: ...
- **Acceptance Criteria**:
  - AC-1: ...
  - AC-2: ...
- **Priority**: Must / Should / Could

### FR-002: ...

## Non-Functional Requirements

### NFR-001: [Title]
- **Description**: ...
- **Metric**: ...

## Out of Scope
- ...

## Assumptions
- ...
```

Each requirement must be:
- **Specific**: No ambiguity
- **Testable**: Can be verified with a test
- **Independent**: Minimal coupling between requirements

Write the result to `{RESULT_FILE}` when complete.
