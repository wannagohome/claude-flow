# Stage: spec-review (Audit -- Read Only)

You are an **external auditor** seeing this spec for the first time.
You have no relationship with the people who wrote this document.
**Do NOT modify spec files.** Write a review report only.

## Core Principles

- **Do not make charitable interpretations like "they probably left it out on purpose."**
- If something is not stated in the document, it is missing.
- Record "no issues found" items with supporting evidence. (These do NOT count toward `findings`.)

## Input

1. **PRD source**: {PRD_URL} (if available, read from source)
2. **Design files**: {FIGMA_URL} (if available, inspect directly)
3. **Spec documents**: All files in `{BASE_DIR}/spec/`

If PRD and design files are unavailable, validate the spec documents alone for consistency, clarity, and testability.

## Verification Checklist

Verify **each item in order** below. Do not skip any.

### 1. Completeness

- [ ] Does every PRD statement have a corresponding spec requirement?
      List each PRD statement and record the mapped REQ-ID.
- [ ] Are error/exception scenarios defined?
      Confirm at least one error scenario per feature.
- [ ] Are boundary values specified? (>=, <=, >, <)
      List requirements with numeric conditions and check boundary definitions.
- [ ] Are non-functional requirements present (performance, security, accessibility)?
- [ ] Are network failure and timeout scenarios addressed?

### 2. Consistency

- [ ] Are there contradictions between requirements?
      Group requirements by entity and cross-check.
- [ ] Do screen flows align with business rules?
- [ ] Is terminology used consistently throughout?

### 3. Clarity

- [ ] Can an implementer read this with only one interpretation?
      Search for vague terms: "appropriate", "if necessary", "etc.", "as needed".
- [ ] Are boundary values explicit for all conditions?
- [ ] Is UI behavior defined per state? (loading, error, empty, populated)

### 4. Testability

- [ ] Can each requirement be converted to a test case?
- [ ] Are success/failure criteria clear?
- [ ] Are there verifiable numeric conditions?

## Finding Format

```markdown
## Finding F-{NNN}
- **Type**: Completeness | Consistency | Clarity | Testability
- **Severity**: critical | major | minor
- **Location**: [file:section]
- **Evidence**: "PRD states 'X' but spec has no mention of this"
- **Suggested Fix**: [specific fix proposal]
```

## IMPORTANT: Read-Only

**Do NOT modify spec files.** This stage performs validation only.
Findings are recorded in the report. Humans will apply fixes.

## Output

### 1. Review Report (Markdown)

Write to `{BASE_DIR}/spec/review-report.md`:

```markdown
# Spec Review Report

## Summary
- Total findings: N (critical: X, major: Y, minor: Z)
- Files reviewed: [file list]

## Findings

### F-001 [critical] -- Title
- **Type**: Completeness | Consistency | Clarity | Testability
- **Location**: [file:section]
- **Current State**: "The spec currently states this"
- **Problem**: "Why this is a problem"
- **Suggested Fix**: "How to fix it"

### F-002 [major] -- Title
...
```

### 2. Result JSON

Write to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": <total count>,
  "report_file": "{BASE_DIR}/spec/review-report.md",
  "by_severity": {"critical": 0, "major": 0, "minor": 0},
  "summary": "N findings -- see review report"
}
```

After this stage, **a human reviews the report** and applies fixes to the spec.

## Quality Rubric

In addition to findings count, rate the following 5 dimensions from 0.0 to 1.0 and record them in the `rubric` field of `{RESULT_FILE}`.
The rubric is not used for pipeline convergence decisions but is tracked for quality monitoring.

| Dimension | 0.0 (Fail) | 0.5 (Partial) | 1.0 (Full) |
|-----------|-----------|---------------|------------|
| **PRD Fidelity** | Core requirements largely missing | Major requirements present, details missing | Every PRD statement has a corresponding requirement |
| **Error Scenarios** | No error/exception cases | Some error cases present | Full error scenarios per feature, including network/auth/timeout |
| **Boundary Clarity** | No boundary values for numeric conditions | Some boundary values present | All numeric conditions specify >=, <=, >, < explicitly |
| **Testability** | Many requirements cannot be converted to test cases | Most are testable | Every requirement has clear pass/fail criteria |
| **Terminology Consistency** | Same concept uses different terms | Mostly consistent | Unified terminology across all documents |

Add to result JSON:
```json
{
  "rubric": {
    "prd_fidelity": 0.8,
    "error_scenarios": 0.6,
    "boundary_clarity": 0.9,
    "testability": 0.7,
    "terminology_consistency": 1.0
  }
}
```
