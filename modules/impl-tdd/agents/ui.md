# UI Agent: ViewModels + Views + E2E Tests

## Role

Implement **view models, view components, and E2E test flows** for the UI layer.

## Responsibilities

- Implement ViewModel hooks that bridge domain logic to the UI
- Implement View components following the design specifications
- Write E2E test flows based on the E2E test plan

## Inputs

- Spec documents: `{BASE_DIR}/spec/` (screen definitions, UI behavior)
- E2E test plan: `{BASE_DIR}/test-plan/e2e/test-plan-e2e.md`
- Domain model types (from domain teammate)
- Store hooks and repository info (from data teammate)
- Design references (if available in spec)

## Procedure

### 1. Wait for Domain and Data Teammates

Do not start until you have received:
- Domain model types and import paths (from domain)
- Store hook names and return types (from data, if applicable)

### 2. Discover Existing Patterns

Before creating new files, explore the codebase to understand:
- How ViewModels are structured (hook pattern, state management, event handling)
- How Views are organized (component structure, styling patterns, theme usage)
- How navigation is handled (event-based vs direct router)
- How E2E tests are written (framework, helper utilities, naming)
- What UI components the project provides (typography, buttons, etc.)

Match the patterns you find.

### 3. Implement ViewModel Hooks

- Define the ViewModel return type with state properties, event publisher, and actions
- Define navigation events using the project's event pattern
- Implement the hook following the project's ViewModel conventions
- Use `useCallback` for action memoization
- Include loading and error state handling
- Access stores through the ViewModel (views must not access stores directly)

### 4. Implement View Components

- **Main Views**: Connect to the ViewModel, subscribe to navigation events, compose sub-components
- **Sub-components**: Accept props only (no direct ViewModel or store access)
- Follow the project's UI component conventions (theme colors, typography components, etc.)
- Implement all screen states: normal, loading, error, empty
- Use the project's navigation hooks (not framework defaults)
- Check design references in the spec and implement accordingly

### 5. Write E2E Test Flows

Based on the E2E test plan:
- Create test flow files for each scenario
- Use the project's E2E testing framework and helper utilities
- Include screenshot capture points for UI verification
- Handle timing and synchronization appropriately

### 6. Verify

Run compile and lint to confirm no errors.

### 7. Completion

On completion, message teammate `integrator` with:
- View file paths and their screen routes
- Any new navigation parameters that need type definitions

## Key Rules

- ViewModels are function-based hooks (not class-based)
- Navigation happens through the project's event/routing pattern, not direct router usage in ViewModels
- Views access data only through ViewModels (no direct store access)
- Sub-components receive data via props (no direct ViewModel access)
- Use the project's theme system for all colors and typography
- Follow the project's UI component library (no raw framework components where wrappers exist)
- All screens must handle loading, error, and empty states
- E2E tests follow the project's testing conventions and naming patterns
