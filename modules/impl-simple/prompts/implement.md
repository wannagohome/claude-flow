# Stage: implement (TDD - Single Session)

Implement the feature using **TDD** based on the spec and test plan.
This is a single-session implementation (no agent teams).

## Inputs

1. **Spec documents**: `{BASE_DIR}/spec/` (read all)
2. **Integration test plan**: `{BASE_DIR}/test-plan/integration/test-plan-integration.md` (if exists)
3. **E2E test plan**: `{BASE_DIR}/test-plan/e2e/test-plan-e2e.md` (if exists)
4. **PICT combinations** (if present): `{BASE_DIR}/test-plan/integration/test-combinations.json`

Read all input files before starting.

## TDD Iron Law

```
Do not write production code unless a failing test demands it.
```

- RED: Write a failing test -> Run it -> Confirm failure
- GREEN: Write the minimal code to make the test pass
- REFACTOR: Clean up while tests still pass

## Procedure

### 1. Explore Existing Patterns

Before writing any code, explore the codebase to understand:
- Project structure and file organization
- Naming conventions (files, types, functions)
- Architecture patterns (layering, dependency direction, DI)
- Test patterns (framework, mock library, naming conventions)
- UI patterns (component structure, styling, theme usage)

Match every pattern you discover.

### 2. Scaffold Types

Start with type definitions only:
- Domain model types
- Repository/service interface types
- DTO types (if applicable)

### 3. TDD Cycle

For each test case in the integration test plan:

1. **Write the test first**
   - Follow the project's test naming conventions
   - Mock only external dependencies; use real code for everything else
2. **RED**: Run the test -> Confirm it fails
3. **GREEN**: Write the minimal production code to pass
4. **REFACTOR**: Clean up while keeping tests green
5. **Commit** after each green cycle

### 4. Implementation Order

Follow the dependency direction (inner layers first):

1. **Domain layer**: Models, interfaces, use cases
2. **Data layer**: DTOs, mappers, repository implementations, stores
3. **UI layer**: ViewModels, Views/Components
4. **Integration**: DI registration, routing configuration

### 5. E2E Tests

After the main implementation is complete:
- Write E2E test flows based on the E2E test plan
- Include screenshot capture points for UI verification

### 6. Final Verification

Run the full verification suite:
```bash
cd {PROJECT_ROOT}
{COMPILE_COMMAND}
{LINT_COMMAND}
{TEST_COMMAND}
```

All must pass with 0 errors.

## Completion Criteria

ALL of the following must be satisfied:

- [ ] All integration tests pass (0 failures)
- [ ] Compile passes (0 errors)
- [ ] Lint passes (0 errors)
- [ ] E2E test flow files are created (if E2E plan exists)
- [ ] DI registrations complete for all new injectable classes
- [ ] Routing configured for all new screens
- [ ] git commit completed
- [ ] Created file list recorded in `{RESULT_FILE}` artifacts

Write results to `{RESULT_FILE}`.
