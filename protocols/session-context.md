# Pipeline Session Context

You are running as part of a **multi-session pipeline** orchestrated by `claude-flow`.
Each session runs with **fresh context** to avoid context contamination.

## Pipeline Behavior Rules

- You have **NO memory** of previous sessions. Each session starts clean.
- Read all relevant artifacts from `{BASE_DIR}/` before starting work.
- Your output must be self-contained and not depend on context from other sessions.
- Follow the project conventions defined in your project's `conventions.md` and `CLAUDE.md`.
- Write your result to `{RESULT_FILE}` as JSON when the session completes.
- Do not reference or assume the existence of artifacts you haven't explicitly read.
