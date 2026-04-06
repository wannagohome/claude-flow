# Stage: test-fix (Round {ROUND}/{MAX_ROUNDS})

Fix failing tests. The spec is the source of truth.

## Core Principles

- Modifying a test just to make it pass is **forbidden** (unless the test contradicts the spec).
- If implementation differs from the spec, fix the implementation.
- Only modify a test if it contradicts the spec.
- Do not fix a failure without understanding its cause.
- **For E2E tests, assess false failure possibility first.** Do not modify code for environment-caused failures.

## Inputs

- Project root: {PROJECT_ROOT}
- Spec documents: `{BASE_DIR}/spec/` (reference when implementation-spec mismatch suspected)
- Integration test plan: `{BASE_DIR}/test-plan/integration/test-plan-integration.md` (if exists)
- Unit test log: `{BASE_DIR}/.pipeline/unit-test.log` (if exists)
- E2E test log: `{BASE_DIR}/.pipeline/e2e-test.log` (if exists)
- E2E screenshots: E2E artifacts directory (failure-point screenshots)

## Procedure

### 1. Identify Test Failures

Do not run tests yourself. Read the log files left by the pipeline.

#### 1a. Unit/Integration Test Log

```
{BASE_DIR}/.pipeline/unit-test.log
```

#### 1b. E2E Test Log + Screenshots

```
{BASE_DIR}/.pipeline/e2e-test.log
{E2E_ARTIFACTS_DIR}          <- Failure-point screenshots/videos
```

#### Analysis Items

Analyze logs to determine:
- List of failing test files (unit + E2E)
- Error messages and stack traces for each failure
- Failure patterns (type error vs runtime error vs assertion failure vs E2E timeout)

### 2. Unit/Integration Failure Analysis

For each failing unit/integration test:

1. **Read the test code**: Understand what the test expects
2. **Read the implementation code**: Understand actual behavior
3. **Check the spec** (when in doubt): Verify correct behavior from spec documents
4. **Determine cause**:
   - Implementation is wrong -> Fix implementation code
   - Test is wrong (contradicts spec) -> Fix test (document reason in a comment)
   - Both are wrong -> Fix both

### 2b. E2E Failure Analysis (False Failure Detection)

When E2E tests fail, **before modifying any code** check the following evidence:

#### Evidence Collection

1. **Check screenshots**: Read failure-point screenshots from the E2E artifacts directory
   - Screen shows expected state but test failed -> false failure (timing issue)
   - Screen shows unexpected state -> real failure
2. **Check error logs**: Identify patterns in the E2E error messages
   - `TimeoutError`, `element not found within timeout` -> potential timing issue
   - `Animation was not idle` -> animation not complete
   - `Device was not idle` -> simulator/emulator state issue
   - `Assertion failed: expected X but got Y` -> real logic failure
3. **Re-run the test**: Run only the failing test again to check
4. **Check view hierarchy** (if available): Examine the native view tree at failure point

#### Determination Criteria

| Evidence | Determination | Action |
|----------|--------------|--------|
| Screenshot normal + timeout error | **False failure** | Add waitFor/retry to test |
| Passes on re-run | **False failure (flaky)** | Improve stability (waitFor, timing) |
| Screenshot abnormal + assertion failure | **Real failure** | Fix implementation code |
| Environment-related error (device idle etc.) | **Environment issue** | Do not fix; record in remaining |

#### False Failure Fix (Stability improvement only)

For false failures, do NOT change logic -- only improve **stability**:
- Add explicit waits/timeouts for element visibility
- Handle animation synchronization
- Add retry configuration

**Logic changes are forbidden. Only adjust timing/waits.**

### 3. Apply Fixes

**When fixing implementation code:**
- Make the smallest change to pass the test
- Ensure other tests do not newly fail
- Follow project conventions
- **If you modified JS/TS source files, run the project's E2E update command** to refresh the E2E binary's JS bundle. Skipping this means fixes will not be reflected in E2E tests.

**When test modification is unavoidable:**
- Document which part of the spec justifies the change in a comment
- Verify test descriptions follow the project's test naming conventions
- Use the project's mock library

### 4. Verification

Do not re-run tests yourself. The pipeline will automatically re-run `run-tests` -> `run-e2e`.
Record your fixes and expected remaining failure count in the result file.

### 5. Type Error Handling

If TypeScript/compile errors exist:

```bash
cd {PROJECT_ROOT}
{COMPILE_COMMAND}
```

Fix compile errors first, then address test failures.

### 6. Commit

After fixes:

```bash
cd {PROJECT_ROOT}
git add -p  # Review and stage changes
git commit -m "test: test-fix Round {ROUND} -- <failure cause summary>"
```

## Allowed / Forbidden

**Allowed:**
- Fixing bugs in implementation code
- Fixing tests that contradict the spec
- Fixing type definitions
- Fixing mock configuration (aligned with test intent)

**Forbidden:**
- Weakening test assertions (`expect(x).toBe(1)` -> `expect(x).toBeDefined()`)
- Skipping failing tests with `skip`/`xit`/`xdescribe`
- Changing implementation without a failing test
- Adding features not in the spec

## Result

```json
{
  "status": "complete",
  "findings": <remaining failures after this round>,
  "fixed": <failures fixed this round>,
  "false_failures": <count determined as false failure>,
  "remaining": [
    {
      "test": "filename > test name",
      "type": "real_failure | false_failure | env_issue",
      "evidence": "screenshot normal + timeout error",
      "reason": "reason it could not be fixed or will be addressed next round"
    }
  ],
  "compile_pass": true,
  "test_pass": <true if remaining real_failures is 0>,
  "summary": "Round {ROUND}: X failures, Y fixed, Z false failures, W remaining"
}
```

Write to `{RESULT_FILE}`.

**`findings` calculation:**
- Both `real_failure` and `false_failure` are included in findings (need re-verification after fix)
- Only `env_issue` is excluded from findings (cannot be solved by code changes)
- When fixable failures reach 0, the pipeline advances to the next stage.
