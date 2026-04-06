#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gate: check-coverage (E2E track)
# Verifies every requirement has at least one covering scenario
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

PIPELINE_JSON="${1:?Usage: $0 <pipeline.json> <base_dir> <project_root>}"
BASE_DIR="${2:?}"
PROJECT_ROOT="${3:?}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[check-coverage]${NC} $*"; }
warn() { echo -e "${YELLOW}[check-coverage]${NC} $*"; }
fail() { echo -e "${RED}[check-coverage]${NC} $*" >&2; }
info() { echo -e "${BLUE}[check-coverage]${NC} $*"; }

E2E_DIR="$BASE_DIR/test-plan/e2e"
SPEC_DIR="$BASE_DIR/spec"
FLOWS_FILE="$E2E_DIR/user-flows.json"
MATRIX_FILE="$E2E_DIR/scenario-traceability-matrix.json"

# ── Validate inputs ──────────────────────────────────────────
[[ -f "$PIPELINE_JSON" ]] || { fail "pipeline.json not found: $PIPELINE_JSON"; exit 1; }
[[ -f "$FLOWS_FILE" ]]    || { fail "user-flows.json not found: $FLOWS_FILE"; exit 1; }
[[ -d "$SPEC_DIR" ]]      || { fail "spec directory not found: $SPEC_DIR"; exit 1; }

command -v jq >/dev/null 2>&1   || { fail "jq is required"; exit 1; }
command -v node >/dev/null 2>&1 || { fail "node is required"; exit 1; }

log "Checking E2E scenario coverage..."

# ── Extract requirement IDs from spec files ───────────────────
log "Extracting requirement IDs from spec files..."

# Collect all REQ-XXX style IDs from spec markdown files
# Also accept variations: REQ-001, R-001, FR-001, NFR-001
SPEC_REQS_RAW=$(grep -rh -oE '(REQ|FR|NFR|R)-[0-9]{3,}' "$SPEC_DIR" 2>/dev/null | sort -u || true)

if [[ -z "$SPEC_REQS_RAW" ]]; then
    warn "No requirement IDs (REQ-XXX format) found in spec files."
    warn "Spec files checked: $SPEC_DIR"
    warn "Skipping coverage check — marking as passed (no structured requirements found)."
    echo ""
    warn "To enable coverage checking, add requirement IDs in the format REQ-001, FR-001, etc."

    # Still generate an empty traceability matrix
    jq -n '{
        generated_at: now | todate,
        note: "No structured requirement IDs found in spec files",
        scenarios_count: (.scenarios | length),
        requirements: [],
        gaps: [],
        coverage_percentage: 100
    }' --slurpfile flows "$FLOWS_FILE" \
    | jq '.scenarios_count = ($flows[0].scenarios | length)' \
    > "$MATRIX_FILE"

    log "Empty traceability matrix written to $MATRIX_FILE"
    exit 0
fi

SPEC_REQ_COUNT=$(echo "$SPEC_REQS_RAW" | wc -l | tr -d ' ')
log "Found $SPEC_REQ_COUNT unique requirement IDs in spec"

# ── Extract covered requirements from user-flows.json ────────
log "Reading scenario coverage from user-flows.json..."

SCENARIO_COUNT=$(jq '.scenarios | length' "$FLOWS_FILE")
[[ "$SCENARIO_COUNT" -gt 0 ]] || { fail "No scenarios found in user-flows.json"; exit 1; }

log "Found $SCENARIO_COUNT scenarios"

# ── Build traceability matrix via Node.js ────────────────────
log "Building scenario-traceability-matrix.json..."

node - "$FLOWS_FILE" "$MATRIX_FILE" "$SPEC_REQS_RAW" <<'JSEOF'
const fs = require('fs');

const flowsFile  = process.argv[2];
const matrixFile = process.argv[3];
const specReqsRaw = process.argv[4] || '';

const flows     = JSON.parse(fs.readFileSync(flowsFile, 'utf8'));
const scenarios = flows.scenarios || [];

// All requirement IDs found in spec
const specReqIds = specReqsRaw
    .split('\n')
    .map(s => s.trim())
    .filter(Boolean);

// Build map: reqId -> covering scenario IDs
const coverageMap = {};
for (const reqId of specReqIds) {
    coverageMap[reqId] = [];
}

for (const scenario of scenarios) {
    const covered = scenario.covers_requirements || [];
    for (const reqId of covered) {
        if (!coverageMap[reqId]) {
            coverageMap[reqId] = [];
        }
        coverageMap[reqId].push(scenario.id);
    }
}

// Identify gaps
const gaps = specReqIds.filter(id => coverageMap[id].length === 0);
const covered_count = specReqIds.filter(id => coverageMap[id].length > 0).length;
const coverage_pct  = specReqIds.length > 0
    ? Math.round((covered_count / specReqIds.length) * 100)
    : 100;

// Build full requirements list
const requirements = specReqIds.map(id => ({
    id,
    covering_scenarios: coverageMap[id],
    is_covered: coverageMap[id].length > 0
}));

// Scenarios with no requirements mapped
const unmapped_scenarios = scenarios
    .filter(s => !s.covers_requirements || s.covers_requirements.length === 0)
    .map(s => s.id);

const matrix = {
    generated_at: new Date().toISOString(),
    spec_requirements_count: specReqIds.length,
    scenarios_count: scenarios.length,
    covered_requirements: covered_count,
    coverage_percentage: coverage_pct,
    gaps: gaps,
    unmapped_scenarios,
    requirements,
    scenarios_index: scenarios.map(s => ({
        id: s.id,
        name: s.name,
        type: s.type || 'unknown',
        priority: s.priority || 'medium',
        covers_requirements: s.covers_requirements || []
    }))
};

fs.writeFileSync(matrixFile, JSON.stringify(matrix));
console.log(`Matrix written: ${specReqIds.length} reqs, ${gaps.length} gaps, ${coverage_pct}% coverage`);
JSEOF

# ── Read matrix results ───────────────────────────────────────
GAP_COUNT=$(jq '.gaps | length' "$MATRIX_FILE")
COVERAGE_PCT=$(jq '.coverage_percentage' "$MATRIX_FILE")
COVERED=$(jq '.covered_requirements' "$MATRIX_FILE")
TOTAL=$(jq '.spec_requirements_count' "$MATRIX_FILE")
UNMAPPED=$(jq '.unmapped_scenarios | length' "$MATRIX_FILE")

# ── Print report ──────────────────────────────────────────────
echo ""
info "=== E2E Coverage Report ==="
info "  Requirements    : $COVERED / $TOTAL covered ($COVERAGE_PCT%)"
info "  Scenarios       : $SCENARIO_COUNT total"
info "  Gaps            : $GAP_COUNT uncovered requirements"

if [[ "$UNMAPPED" -gt 0 ]]; then
    warn "  Unmapped scenarios (no covers_requirements): $UNMAPPED"
    jq -r '.unmapped_scenarios[]' "$MATRIX_FILE" | while read -r sid; do
        warn "    - $sid"
    done
fi

if [[ "$GAP_COUNT" -gt 0 ]]; then
    echo ""
    fail "=== GAPS FOUND ==="
    jq -r '.gaps[]' "$MATRIX_FILE" | while read -r rid; do
        fail "  UNCOVERED: $rid"
    done
    echo ""

    # Classify gaps by prefix to determine criticality
    # Requirements starting with REQ- or FR- are considered critical
    CRITICAL_GAPS=$(jq -r '.gaps[] | select(test("^(REQ|FR)-"))' "$MATRIX_FILE" | wc -l | tr -d ' ')

    if [[ "$CRITICAL_GAPS" -gt 0 ]]; then
        fail "  $CRITICAL_GAPS critical requirement(s) uncovered. Fix before proceeding."
        echo ""
        fail "  Add scenarios to user-flows.json that cover the above requirements."
        echo ""
        exit 1
    else
        warn "  All gaps are in non-critical requirements (NFR/R prefix)."
        warn "  Proceeding with warning. Consider adding scenarios in the next review round."
        echo ""
        # Write updated matrix with warning note
        jq '.note = "Gaps present but all in non-critical requirements (NFR/R)"' \
            "$MATRIX_FILE" > "${MATRIX_FILE}.tmp" && mv "${MATRIX_FILE}.tmp" "$MATRIX_FILE"
        exit 0
    fi
fi

echo ""
log "=== Coverage check PASSED ==="
log "  All $TOTAL requirements have at least one covering scenario."
log "  Matrix written to: $MATRIX_FILE"
echo ""
exit 0
