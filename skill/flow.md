---
name: flow
description: "Multi-session pipeline orchestrator. Runs claude -p sessions with fresh context per stage."
---

# claude-flow

Multi-session pipeline orchestrator that eliminates context contamination 
by running each stage in a fresh `claude -p` session with Writer/Reviewer separation.

## Commands

Execute the corresponding bash command:

| Slash Command | Bash Command |
|---|---|
| `/flow setup` | `claude-flow setup` |
| `/flow init <feature> [--figma URL] [--prd URL]` | `claude-flow init <feature> [flags]` |
| `/flow run <feature> [--stage STAGE]` | `claude-flow run <feature> [flags]` |
| `/flow status <feature>` | `claude-flow status <feature>` |
| `/flow stages` | `claude-flow stages` |
| `/flow <feature> --edit "prompt"` | `claude-flow <feature> --edit "prompt"` |
| `/flow <feature> --continue` | `claude-flow <feature> --continue` |
| `/flow <feature> --force-continue` | `claude-flow <feature> --force-continue` |
| `/flow <feature> --review` | `claude-flow <feature> --review` |

## Pipeline Phases

1. **Spec** — Extract/define requirements and structured spec
2. **Test Plan** — Generate test combinations (PICT) and E2E scenarios
3. **Design** — Interface-level system design
4. **Implementation** — TDD implementation with agent teams
5. **Verification** — Test execution, fix loops, UI verification

Each phase runs in fresh context with deterministic gates between stages.

## Setup

If `.claude/flow.yaml` doesn't exist, run `claude-flow setup` first.
