# Stage: requirements-review

Review the defined requirements for internal consistency and completeness.

## Input

- `{BASE_DIR}/spec/requirements.md`
- `{BASE_DIR}/spec/requirements-input.md` (original user description)

## Review Criteria

Unlike spec-review which checks fidelity to an external PRD, this review checks **internal quality**:

1. **Internal Consistency**: Do any requirements contradict each other?
2. **Completeness**: Are there obvious gaps or missing edge cases?
3. **Feasibility**: Can each requirement be implemented with the current tech stack?
4. **Testability**: Can each acceptance criterion be verified?
5. **Scope Alignment**: Do requirements match the user's original description?
6. **Boundary Clarity**: Are limits, thresholds, and edge cases defined?

## Task

For each finding:
1. Identify the specific requirement (e.g., FR-003)
2. Describe the issue
3. Suggest a fix
4. Apply the fix directly to requirements.md

## Result

Write to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": <number of issues found and fixed>,
  "summary": "N issues found and fixed in requirements.md"
}
```
