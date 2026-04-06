# claude-flow

Multi-session pipeline orchestrator for Claude Code. Runs each stage in a fresh `claude -p` session with Writer/Reviewer separation to eliminate context contamination.

## Key Features

- **Session isolation** — Each stage runs with fresh context, preventing hallucination carryover
- **Writer/Reviewer separation** — Generation and verification in separate adversarial sessions
- **Deterministic gates** — Shell scripts validate coverage and traceability (not LLM)
- **Modular architecture** — Swap modules (e2e-detox ↔ e2e-playwright), add providers (Figma, Confluence)
- **Declarative config** — YAML pipeline definition with preset inheritance
- **Parallel execution** — Independent stages run concurrently
- **Resumable** — Interrupt and resume from any point

## Quick Start

```bash
# Install
npm install -g @wannagohome/claude-flow

# Initialize project
cd my-project
claude-flow setup

# Edit .claude/flow/conventions.md with your project rules

# Start a feature pipeline
claude-flow init my-feature --figma "https://figma.com/file/..."
claude-flow run my-feature
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Core Engine                                     │
│  State management, dependency resolution,        │
│  parallel execution, review loops, CLI           │
├─────────────────────────────────────────────────┤
│  Protocols                                       │
│  Session context, Write/Review behavior rules    │
├─────────────────────────────────────────────────┤
│  Modules                                         │
│  Swappable stage bundles + prompts + gates        │
├─────────────────────────────────────────────────┤
│  Providers                                       │
│  External tool integration (Figma, Confluence)   │
├─────────────────────────────────────────────────┤
│  Project Config                                  │
│  flow.yaml + conventions.md + prompt overrides   │
└─────────────────────────────────────────────────┘
```

## Pipeline Phases

```
Spec ──> Test Plan ──> Design ──> Implementation ──> Verification
 │          │            │            │                   │
 │    ┌─────┴─────┐      │     ┌──────┴──────┐           │
 │    │ Integration│      │     │  TDD + Code │           │
 │    │ (PICT)     │      │     │  Review     │           │
 │    ├────────────┤      │     ├─────────────┤           │
 │    │ E2E        │      │     │  Test Run   │           │
 │    │ Scenarios  │      │     │  + Fix Loop │           │
 │    └────────────┘      │     └─────────────┘           │
 │                        │                               │
 ▼ manual gate       ▼ manual gate                   ▼ ui-verify
```

Each stage follows: **Write → Review (multi-round) → Gate → Manual approval**

## Configuration

```yaml
# .claude/flow.yaml
extends: full-tdd

project:
  conventions: ./flow/conventions.md

providers:
  figma:
    enabled: true
  confluence:
    enabled: true

phases:
  spec:
    strategy: from-requirements    # or "from-scratch"
  test-plan:
    modules: [tc-pict, e2e-detox]
    manual_gate: true
  design:
    modules: [design-interface]
  impl:
    modules: [impl-tdd]

models:
  write: claude-opus-4-6
  review: claude-sonnet-4-6
  escalation:
    model: claude-opus-4-6
    after_round: 5

review:
  max_rounds: 3

test:
  unit:
    command: "npm test"
  e2e:
    command: "npm run e2e"
```

## Modules

| Module | Phase | Description |
|--------|-------|-------------|
| `spec-from-requirements` | spec | Extract structured spec from existing PRD/requirements |
| `spec-from-scratch` | spec | Define requirements and spec from user description |
| `tc-pict` | test-plan | PICT-based combinatorial test planning |
| `tc-manual` | test-plan | Manual test case writing (no PICT) |
| `e2e-detox` | test-plan | Detox E2E scenario planning |
| `design-interface` | design | Interface-level system design |
| `impl-tdd` | impl | TDD implementation with 4-member agent team |
| `impl-simple` | impl | Single-session implementation |
| `verify-ui` | verify | UI verification against designs |

### Custom Modules

Create a module in your project:

```
.claude/flow/modules/my-module/
├── module.yaml
├── prompts/
│   ├── write.md
│   └── review.md
└── gates/
    └── validate.sh
```

Or publish as npm: `npm publish` as `claude-flow-module-{name}`

## Providers

Providers inject external tool context into prompts without modifying stage prompts.

**Built-in:** `figma`, `confluence`

### Custom Provider

```
.claude/flow/providers/storybook/
├── provider.yaml
└── fragments/
    └── implement.md
```

```yaml
# provider.yaml
name: storybook
description: "Storybook component preview"
capability:
  description: "Preview components in Storybook"
variables:
  - name: STORYBOOK_URL
    cli_flag: --storybook
    optional: true
    persist: true
fragments:
  - match: { phase: impl, type: write }
    file: fragments/implement.md
```

## Presets

| Preset | Phases |
|--------|--------|
| `full-tdd` | Spec, Test Plan, Design, Implementation |
| `impl-only` | Design, Implementation |
| `spec-only` | Spec, Test Plan |

Extend with `extends: full-tdd` in your flow.yaml.

## Prompt Override

Override any module prompt by placing a file with the same name:

```
.claude/flow/prompts/implement.md    # overrides impl-tdd's default
```

## CLI Commands

```
claude-flow setup                          # Interactive project setup
claude-flow init <feature> [--figma URL]   # Initialize pipeline
claude-flow run <feature>                  # Execute pipeline
claude-flow run <feature> --stage <stage>  # Run specific stage
claude-flow status <feature>               # Show progress
claude-flow stages <feature>               # Show stage graph
claude-flow <feature> --edit "prompt"      # AI-assisted editing
claude-flow <feature> --review             # Re-run spec review
claude-flow <feature> --continue           # Pass manual gate
claude-flow <feature> --force-continue     # Force past blockers
```

## Claude Code Integration

Install the skill for `/flow` slash commands:

```bash
ln -s $(npm root -g)/@wannagohome/claude-flow/skill/flow.md ~/.claude/commands/flow.md
```

Then use `/flow init my-feature`, `/flow run my-feature`, etc.

## Prerequisites

- [jq](https://stedolan.github.io/jq/) — JSON processing
- [yq](https://github.com/mikefarah/yq) — YAML processing
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) — `claude -p` for sessions
- [PICT](https://github.com/microsoft/pict) — (optional) for tc-pict module

## License

MIT
