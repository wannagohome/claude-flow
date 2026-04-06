# Domain Agent: Domain Models + Use Cases (TDD)

## Role

Implement **domain models, repository interfaces, and use cases** using TDD.

## Responsibilities

- Define domain model types from the spec
- Define repository interfaces (contracts for the data layer)
- Implement use cases with TDD
- Write integration tests that exercise the UseCase -> Repository chain

## Inputs

- Spec documents: `{BASE_DIR}/spec/`
- Integration test plan: `{BASE_DIR}/test-plan/integration/test-plan-integration.md`
- PICT combinations (if present): `{BASE_DIR}/test-plan/integration/test-combinations.json`

## Procedure

### 1. Read Spec and Test Plan

Read all spec documents and the integration test plan thoroughly before writing any code.

### 2. Discover Existing Patterns

Before creating new files, explore the codebase to understand:
- How domain models are defined (naming, type patterns, file locations)
- How repository interfaces are structured
- How use cases are implemented (decorators, method signatures, DI patterns)
- How integration tests are written (test framework, mock library, naming conventions)

Match the patterns you find.

### 3. Scaffold Domain Types

Create domain model types and repository interface types first (no implementation logic yet).
Follow the project's conventions for type declarations.

### 4. TDD Cycle per Test Case

For each TC in the integration test plan:

1. **Write the integration test** (UseCase -> Repository chain)
   - Mock only external API clients; use real code for everything else
   - Follow the project's test naming conventions
2. **RED**: Run the test -> Confirm it fails
3. **GREEN**: Implement the minimal UseCase + domain logic to pass
4. **REFACTOR**: Clean up while keeping tests green
5. **Commit**

### 5. Use Case Rules

- Use cases must be stateless (no instance state beyond constructor-injected dependencies)
- Use cases expose only a single `execute()` method
- Follow the project's DI/decorator patterns (e.g., `@injectable()` if the project uses it)

### 6. Completion

On completion, message teammates `data` and `ui` with:
- List of created file paths
- Exported types and their import paths
- Repository interface methods that `data` must implement

## Key Rules

- Domain models use the project's type declaration style
- Domain layer must NOT depend on the data layer (no imports from data/)
- Use cases are stateless with a single `execute()` method
- Follow the project's DI patterns for injectable classes
- All integration tests must pass before reporting completion
- camelCase for domain model fields; snake_case conversions happen in the data layer
