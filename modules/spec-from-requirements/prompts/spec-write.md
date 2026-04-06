# Stage: spec-write

Analyze requirement documents to produce a structured, split-file specification.
Use an **Agent Team** so that 3 teammates work in parallel.
Gap detection is performed in a separate session (spec-review) with fresh context.

## Input

- Feature name: {FEATURE}
- **Requirements input**: `{BASE_DIR}/spec/requirements-input.md` -- **Read this first**
- PRD (if available): {PRD_URL}
- Design files (if available): {FIGMA_URL}

`requirements-input.md` contains user-authored requirements.
Use this as the primary source. PRD and design files are supplementary material.

## Output Directory

```
{BASE_DIR}/
├── spec/
│   ├── _overview.md
│   ├── _screen-feature-map.md
│   ├── {sub-feature-1}.md
│   └── {sub-feature-2}.md
└── README.md
```

## Agent Team

Create the following Agent Team:

Team name: spec-{FEATURE}
Use Delegate mode.

### Teammate 1 - "analyst" (requirements-analyst)

```
Extract the functional requirements for: {FEATURE}

- PRD: {PRD_URL}
- Analyze the PRD/requirements documents to extract:
  - Feature overview and business rules
  - Acceptance criteria for each requirement
- Output: Split files per sub-feature under {BASE_DIR}/spec/
- Share screen-related information with teammate 'ux' via direct message

Requirements Analyst Responsibilities:
1. Read the PRD/requirements document thoroughly
2. Identify all functional requirements and assign REQ-IDs
3. Extract business rules, constraints, and policies
4. Document acceptance criteria for each requirement
5. Identify non-functional requirements (performance, security, accessibility)
6. Flag ambiguities or gaps in the source document
7. Coordinate with 'ux' and 'figma' teammates on screen-level details
```

### Teammate 2 - "figma" (design-mapper)

```
Explore and map the design structure for: {FEATURE}

- Design files: {FIGMA_URL}
- If no design URL is provided, skip this teammate's work and note "No design files available"

Design Mapper Responsibilities:
1. Explore the design file structure (screens, components, variants)
2. Map each screen to a unique identifier
3. Document component hierarchy per screen
4. Identify design states (default, hover, error, loading, empty, etc.)
5. Note responsive breakpoints or platform variations if present
6. Add a "Design Mapping" section to each sub-feature spec file
7. Share discovered screen structure with teammates 'ux' and 'analyst'
```

### Teammate 3 - "ux" (ux-analyst)

```
Define user scenarios for: {FEATURE}

- Receive findings from 'analyst' and 'figma' teammates as you work

UX Analyst Responsibilities:
1. Define the primary user flows (happy paths)
2. Define alternative and error flows
3. Document screen transitions and navigation paths
4. Specify UI states per screen (loading, error, empty, populated)
5. Define user actions and their expected system responses
6. Add a "User Scenarios" section to each sub-feature spec file
7. Notify 'analyst' when scenario definitions are complete
```

## File Ownership

| Teammate | Owned Files |
|----------|------------|
| analyst  | `spec/_overview.md`, `spec/{sub-feature-*}.md` (requirements sections) |
| figma    | `spec/{sub-feature-*}.md` (design mapping sections only) |
| ux       | `spec/{sub-feature-*}.md` (user scenario sections only) |

## Completion Criteria

Complete ONLY when **all** items below are satisfied. Do not rush to finish because context is growing.

- [ ] Spec files contain requirements sections (analyst)
- [ ] Spec files contain user scenario sections (ux)
- [ ] Spec files contain design mapping sections (figma) -- or noted as N/A if no design files
- [ ] `_overview.md` created
- [ ] `_screen-feature-map.md` created
- [ ] `README.md` created

Write the result to `{RESULT_FILE}` when complete.
