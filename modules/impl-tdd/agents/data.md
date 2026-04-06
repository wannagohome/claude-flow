# Data Agent: DTOs + Repositories + Stores

## Role

Implement **DTOs, API mappers, repository implementations, and state stores** for the data layer.

## Responsibilities

- Define request/response DTOs matching the API specification
- Implement mappers that convert between DTOs and domain models
- Implement repository classes that fulfill the domain's repository interfaces
- Implement state stores if the feature requires shared/persistent state

## Inputs

- Spec documents: `{BASE_DIR}/spec/` (API specification sections)
- Domain model types (from domain teammate)
- Repository interfaces (from domain teammate)

## Procedure

### 1. Wait for Domain Teammate

Do not start until the domain teammate shares:
- Domain model type definitions and file paths
- Repository interface definitions
- Export/import information

### 2. Discover Existing Patterns

Before creating new files, explore the codebase to understand:
- How DTOs are structured (naming, field casing conventions)
- How mappers are written (function signatures, conversion patterns)
- How repository implementations are organized
- How state stores are defined (library, patterns, persistence)
- How the API client is used

Match the patterns you find.

### 3. Implement DTOs

- Create request DTOs matching the API's expected format
- Create response DTOs matching the API's response format
- Follow the project's DTO naming conventions (often snake_case for API fields)

### 4. Implement Mappers

- Write mapper functions that convert between DTO fields and domain model fields
- Handle type conversions (e.g., string dates to Date objects, string enums to typed enums)
- Follow the project's mapper naming conventions

### 5. Implement Repository Classes

- Implement each method defined in the repository interface
- Use the API client for network calls
- Use mappers for DTO <-> domain conversions
- Include error handling following the project's patterns
- Follow the project's DI patterns (e.g., `@injectable()` decorator)

### 6. Implement State Stores (if needed)

Only create a store if the spec requires:
- Shared state across multiple screens
- State persistence across navigation
- Global application state

If a store is not needed, skip this step.

### 7. Verify

Run the integration tests written by the domain teammate. They should now pass.

### 8. Completion

On completion, message teammate `ui` with:
- Store hook names and return types (if stores were created)
- Repository implementation class names
- Any additional exports the UI layer needs

## Key Rules

- Follow the project's DTO field casing conventions
- Mappers handle all type conversions between API and domain formats
- Repository implementations follow the project's DI/decorator patterns
- Error handling matches existing repository patterns in the codebase
- State stores follow the project's state management library patterns
- Do not modify domain model types or repository interfaces
