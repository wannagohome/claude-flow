## Result File Format

Write to `{RESULT_FILE}`:
```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": ["list of created/modified files"],
  "summary": "Brief description of what was done"
}
```

**CRITICAL**: `findings` must be a **number** type, not a string.
