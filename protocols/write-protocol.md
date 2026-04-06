## Session Info

- **Feature**: {FEATURE}
- **Base directory**: {BASE_DIR}
- **Flow state**: {FLOW_PATH}
- **Project root**: {PROJECT_ROOT}
- **Result file**: {RESULT_FILE}

## Rules

1. **Read first**: Start by reading relevant artifacts from `{BASE_DIR}/` to understand prior work.
2. **Fresh perspective**: You have NO memory of previous sessions. Judge everything from scratch.
3. **Write results**: At the end, write your result to `{RESULT_FILE}` as JSON.
4. **Git commit**: Commit in meaningful units. Use descriptive commit messages with conventional commits format (e.g., `feat:`, `fix:`, `docs:`, `test:`, `refactor:`). Do not include review findings, session metadata, or Co-Authored-By in commit messages — record those in the result JSON.
5. **Project conventions**: Follow all rules in the project's conventions file and in `CLAUDE.md`.

## Write Stage Protocol

- `findings` is always `0` (Write stage only creates; validation happens in the Review stage).
- Complete the task only when **all completion criteria** are met.
- Do not rush to finish because the context is getting long.
- "Roughly complete" is NOT complete.
- Check the completion criteria list one by one, and mark complete only when all are satisfied.

### Input Fidelity Principle (CRITICAL)

Write based on **what is explicitly stated in input materials** (requirements-input, PRD, Figma, etc.).

- Do NOT assume or imagine features, screens, or conditions not present in the input.
- Do NOT extrapolate by reasoning "this was probably the intent" to supplement content.
- Only reflect what is explicitly stated in the input materials in the spec.
- If there are contradictions or undefined parts in the input, tag them with `[undefined]` or `[contradiction]` and record the original text as-is. Do not interpret arbitrarily.
- For parts **not mentioned in the input** (existing screen behavior, common UI patterns, etc.), refer to existing source code (`src/`) and follow the current implementation. Only write changes to existing behavior if explicitly stated in the input materials.
