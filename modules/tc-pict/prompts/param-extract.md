# Stage: param-extract

Analyze the spec documents to extract a PICT-compatible parameter model.

## Input

- **Feature**: {FEATURE}
- **Spec documents**: `{BASE_DIR}/spec/` — Read all files

Read all spec files first. If no files are found, report an error and stop immediately.

## Parameter Extraction Procedure

Read the files in `{BASE_DIR}/spec/` sequentially and perform the following steps.

### 1. Identify Requirements

Extract all requirements with REQ-IDs from each spec file.
If a requirement has no REQ-ID, assign a temporary ID in the format `{filename}-{sequence}`.

### 2. Parameter Identification Criteria

For each requirement, extract **variables that affect behavior** as parameters.

Parameter candidate categories:

| Category | Examples |
|----------|----------|
| Business inputs | Quantity, amount, date, classification |
| State values | Login status, permission level, subscription state |
| System/environment | Network status, auth token validity |
| Boundary values | Min/max allowed values, empty values, null |
| Error cases | Server errors, timeouts, validation failures |

### 3. Value List Rules

For each parameter, always include the following three kinds of values:

- **Normal values**: Typical valid inputs
- **Boundary values**: Minimum, maximum, boundary +/-1 (for numeric/range types)
- **Abnormal values**: Empty, null, format errors, out-of-range

### 4. Constraints

If there are dependencies between parameters, describe them in PICT syntax:

```
IF [ParameterA] = "ValueX" THEN [ParameterB] <> "ValueY";
```

## Output Format

Write a JSON file with the following structure to `{BASE_DIR}/test-plan/integration/parameter-model.json`.

**WARNING: This schema is shared with the pict-generate and check-traceability gates. Follow this structure exactly.**

```json
{
  "feature": "{FEATURE}",
  "extractedAt": "<ISO 8601 timestamp>",
  "parameters": [
    {
      "name": "ParameterName",
      "values": ["normal1", "boundary_min", "boundary_max", "abnormal"],
      "boundary_values": ["boundary_min", "boundary_max"],
      "type": "enum",
      "risk": "high",
      "notes": "Boundary justification or special notes (optional)"
    }
  ],
  "requirements": [
    {
      "id": "REQ-001",
      "description": "Requirement description",
      "sourceFile": "spec file path",
      "parameters": ["ParameterName1", "ParameterName2"]
    }
  ],
  "constraints": [
    "IF [ParameterA] = 'X' THEN [ParameterB] <> 'Y';"
  ]
}
```

### Schema Rules

- `parameters`: **array** — each item requires `name`, `values`, `type`, `risk`
- `parameters[].boundary_values`: boundary values listed separately (used by the PICT gate for boundary coverage verification)
- `requirements`: **array** — each item requires `id`, `description`, `parameters` (array of parameter names)
- `requirements[].parameters`: list of `name` values from the parameters array that relate to this requirement

### type Criteria

| type | Criteria |
|------|----------|
| `enum` | Finite enumerable set |
| `range` | Continuous numeric range (must include boundary values) |
| `boolean` | Only true/false |

### risk Criteria

| risk | Criteria |
|------|----------|
| `high` | Data loss or payment error possible on failure |
| `medium` | Feature malfunction, user confusion possible |
| `low` | Display errors or minor side effects |

## Completion Criteria

- All REQ-IDs from `{BASE_DIR}/spec/` exist in the `requirements` array
- Each REQ's `parameters` field maps to `name` values in the `parameters` array
- Each parameter has normal, boundary, and abnormal values in `values`
- Boundary values are separately listed in `boundary_values`
- Inter-parameter constraints are described in PICT syntax in `constraints`
- JSON is saved to `{BASE_DIR}/test-plan/integration/parameter-model.json`

Write the result to `{RESULT_FILE}`:

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": ["{BASE_DIR}/test-plan/integration/parameter-model.json"],
  "summary": "N REQs, M parameters extracted, K constraints"
}
```
