# Stage: requirements-research

Analyze the domain and research similar solutions for the feature: {FEATURE}

## Input

- Feature description: `{BASE_DIR}/spec/requirements-input.md` -- **Read this first**

## Task

1. **Read requirements-input.md** to understand what the user wants to build
2. **Domain research**: Analyze what similar products/features exist in this space
3. **Technical feasibility**: Check the current codebase to understand constraints
   - Read relevant source code under the project root
   - Identify existing patterns, frameworks, and architectural conventions
4. **Gap identification**: What questions remain unanswered?

## Output

Write to `{BASE_DIR}/spec/research-notes.md`:

```markdown
# Research Notes: {FEATURE}

## Domain Analysis
[Summary of domain research, similar solutions, industry patterns]

## Technical Context
[Current codebase structure, relevant existing code, constraints]

## Key Considerations
[Important decisions that need to be made]

## Open Questions
[Questions that need user clarification]
```

Write the result to `{RESULT_FILE}` when complete.
