# Stage: implement (TDD)

Implement the feature using **TDD** based on the spec and test plan.
Use an **Agent Team** where each teammate independently implements their architectural layer.

## Inputs

1. **Spec documents**: `{BASE_DIR}/spec/` (read all)
2. **Integration test plan**: `{BASE_DIR}/test-plan/integration/test-plan-integration.md`
3. **E2E test plan**: `{BASE_DIR}/test-plan/e2e/test-plan-e2e.md`
4. **PICT combinations** (if present): `{BASE_DIR}/test-plan/integration/test-combinations.json`

Read all input files before starting.

## TDD Iron Law

```
Do not write production code unless a failing test demands it.
```

- RED: Write a failing test -> Run it -> Confirm failure
- GREEN: Write the minimal code to make the test pass
- REFACTOR: Clean up while tests still pass

## Agent Team

Team name: impl-{FEATURE}
Use delegate mode.
Require plan approval from the domain teammate.

### Teammate 1 - "domain" (Domain Models + Use Cases)
```
Implement the Domain Layer with TDD for: {FEATURE}

Input:
- Spec: {BASE_DIR}/spec/
- Test Plan: {BASE_DIR}/test-plan/integration/test-plan-integration.md
- Follow the domain agent instructions

TDD procedure based on test-plan-integration.md TCs:
1. Scaffold first: Define domain model types + repository interface types only
2. Write integration tests per TC (UseCase -> Repository chain)
   - Mock only external API clients; use real code for everything else
3. RED: Run tests -> Confirm failures
4. GREEN: Implement UseCase + Domain logic
5. REFACTOR -> git commit

On completion:
Message teammates 'data' and 'ui' directly with:
- Created file paths, exported type list, import paths
```

### Teammate 2 - "data" (DTO + Repository + Store)
```
Implement the Data Layer for: {FEATURE}

Follow the data agent instructions.

Procedure:
- Wait for domain teammate to share domain model information before starting
- Implement the data layer so that domain's integration tests pass
- Implement DTOs, mappers, repository implementations, and state stores

On completion:
Message teammate 'ui' directly with:
- Store hook names/return types, repository implementation class names
```

### Teammate 3 - "ui" (ViewModel + View + E2E)
```
Implement the UI Layer for: {FEATURE}

Input:
- Spec: {BASE_DIR}/spec/
- E2E Plan: {BASE_DIR}/test-plan/e2e/test-plan-e2e.md
- Follow the UI agent instructions

Procedure:
- Wait for information from domain and data teammates before starting
- Implement ViewModel hooks
- Implement View components (check design references if available)
- Write E2E test flows based on the E2E test plan

On completion:
Message teammate 'integrator' with View file paths and screen route information
```

### Teammate 4 - "integrator" (DI + Routing + Verification)
```
Complete integration for: {FEATURE}

Follow the integrator agent instructions.

Procedure:
- Wait for all other teammates (domain, data, ui) to complete before starting
- Register DI container tokens and bindings for all new classes
- Create routing configuration for new screens/pages
- Run compile, lint, and test commands
- Verify all integration tests pass

Report compile/lint/test results to the lead.
```

## File Ownership

| Teammate | Owned Files |
|----------|------------|
| domain | Domain models, interfaces, use cases, integration tests |
| data | DTOs, mappers, repository implementations, stores |
| ui | ViewModels, Views, E2E test flows |
| integrator | DI container config, routing config |

## Completion Criteria

ALL of the following must be satisfied. Do not rush to finish because context is getting long.
"Approximately done" is not done.

- [ ] All integration tests pass (0 failures)
- [ ] Compile passes (0 errors)
- [ ] Lint passes (0 errors)
- [ ] E2E test flow files are created
- [ ] git commit completed
- [ ] File list from each teammate recorded in `{RESULT_FILE}` artifacts

**If integration tests or compilation fail when this stage completes, the next code-review stage will catch it immediately and loop back.**

Write results to `{RESULT_FILE}`.
