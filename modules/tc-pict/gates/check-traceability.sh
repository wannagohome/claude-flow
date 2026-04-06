#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gate: check-traceability (Integration track)
# Verifies every requirement has at least one test combination,
# and boundary values are represented in the combination set.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

PIPELINE_JSON="${1:?Usage: $0 <pipeline.json> <base_dir> <project_root>}"
BASE_DIR="${2:?}"
PROJECT_ROOT="${3:?}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[check-traceability]${NC} $*"; }
warn() { echo -e "${YELLOW}[check-traceability]${NC} $*"; }
fail() { echo -e "${RED}[check-traceability]${NC} $*" >&2; }
info() { echo -e "${BLUE}[check-traceability]${NC} $*"; }

INTEG_DIR="$BASE_DIR/test-plan/integration"
MATRIX_FILE="$INTEG_DIR/traceability-matrix.json"
PARAM_FILE="$INTEG_DIR/parameter-model.json"
COMBOS_FILE="$INTEG_DIR/test-combinations.json"

# ── Validate inputs ──────────────────────────────────────────
[[ -f "$PIPELINE_JSON" ]] || { fail "pipeline.json not found: $PIPELINE_JSON"; exit 1; }

MISSING_FILES=()
[[ -f "$MATRIX_FILE" ]] || MISSING_FILES+=("traceability-matrix.json")
[[ -f "$PARAM_FILE" ]]  || MISSING_FILES+=("parameter-model.json")
[[ -f "$COMBOS_FILE" ]] || MISSING_FILES+=("test-combinations.json")

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    fail "Required files not found in $INTEG_DIR:"
    for f in "${MISSING_FILES[@]}"; do
        fail "  - $f"
    done
    fail "Run the pict-generate gate first."
    exit 1
fi

command -v jq >/dev/null 2>&1   || { fail "jq is required"; exit 1; }
command -v node >/dev/null 2>&1 || { fail "node is required"; exit 1; }

log "Checking integration test traceability..."

# ── Read matrix summary ───────────────────────────────────────
TOTAL_REQS=$(jq '.requirements | length' "$MATRIX_FILE")
UNCOVERED_COUNT=$(jq '.uncovered_requirements | length' "$MATRIX_FILE")
TOTAL_COMBOS=$(jq '.combinations | length' "$COMBOS_FILE")
TOTAL_PARAMS=$(jq '.parameters | length' "$PARAM_FILE")

log "Requirements: $TOTAL_REQS | Combinations: $TOTAL_COMBOS | Parameters: $TOTAL_PARAMS"

# ── 1. Requirement -> Combination Coverage ────────────────────
echo ""
info "=== 1. Requirement Coverage ==="

if [[ "$TOTAL_REQS" -eq 0 ]]; then
    warn "No requirements defined in traceability-matrix.json."
    warn "Add a 'requirements' array to parameter-model.json to enable traceability."
else
    if [[ "$UNCOVERED_COUNT" -gt 0 ]]; then
        fail "Requirements with no covering combination:"
        jq -r '.uncovered_requirements[]' "$MATRIX_FILE" | while read -r rid; do
            fail "  UNCOVERED: $rid"
        done
        COVERAGE_FAILURES=true
    else
        log "All $TOTAL_REQS requirements have at least one covering combination."
        COVERAGE_FAILURES=false
    fi
fi

# ── 2. Boundary Value Verification ───────────────────────────
echo ""
info "=== 2. Boundary Value Coverage ==="

BOUNDARY_REPORT=$(node - "$PARAM_FILE" "$COMBOS_FILE" <<'JSEOF'
const fs = require('fs');
const model  = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const combos = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));

const params       = model.parameters || [];
const combinations = combos.combinations || [];

// Identify boundary values per parameter
// Convention: values tagged with "boundary: true" in parameter-model.json
// OR values that look like boundary conditions by heuristic:
//   - Numeric: 0, -1, min, max, empty string
//   - String: "empty", "none", "null", "boundary", "min", "max", "limit"
//   - Explicit: parameter has "boundary_values" array

const BOUNDARY_HINTS = /^(0|-1|empty|none|null|min|max|limit|boundary|edge|invalid|overflow|underflow)$/i;

const report = {
    parameters: [],
    all_boundaries_covered: true,
    missing_boundaries: []
};

for (const param of params) {
    const paramName = param.name;
    const allValues = param.values || [];

    // Determine boundary values for this parameter
    let boundaryValues = [];

    if (param.boundary_values && param.boundary_values.length > 0) {
        // Explicit declaration takes precedence
        boundaryValues = param.boundary_values;
    } else {
        // Heuristic detection
        boundaryValues = allValues.filter(v =>
            BOUNDARY_HINTS.test(String(v)) ||
            (param.type === 'numeric' && (v == 0 || v == -1))
        );
    }

    if (boundaryValues.length === 0) {
        report.parameters.push({
            name: paramName,
            boundary_values: [],
            status: 'no_boundaries_identified'
        });
        continue;
    }

    // Check which boundary values appear in at least one combination
    const coveredBoundaries = new Set();
    for (const combo of combinations) {
        const val = combo.parameters[paramName];
        if (val !== undefined && boundaryValues.map(String).includes(String(val))) {
            coveredBoundaries.add(String(val));
        }
    }

    const missingBoundaries = boundaryValues
        .map(String)
        .filter(v => !coveredBoundaries.has(v));

    if (missingBoundaries.length > 0) {
        report.all_boundaries_covered = false;
        report.missing_boundaries.push({
            parameter: paramName,
            missing: missingBoundaries,
            covered: [...coveredBoundaries]
        });
    }

    report.parameters.push({
        name: paramName,
        boundary_values: boundaryValues.map(String),
        covered: [...coveredBoundaries],
        missing: missingBoundaries,
        status: missingBoundaries.length === 0 ? 'covered' : 'partial'
    });
}

process.stdout.write(JSON.stringify(report));
JSEOF
)

BOUNDARY_ALL_COVERED=$(echo "$BOUNDARY_REPORT" | jq -r '.all_boundaries_covered')
BOUNDARY_MISSING_COUNT=$(echo "$BOUNDARY_REPORT" | jq '.missing_boundaries | length')
BOUNDARY_NO_IDENT=$(echo "$BOUNDARY_REPORT" | jq '[.parameters[] | select(.status == "no_boundaries_identified")] | length')

if [[ "$BOUNDARY_NO_IDENT" -gt 0 ]]; then
    warn "Parameters with no identified boundary values: $BOUNDARY_NO_IDENT"
    echo "$BOUNDARY_REPORT" | jq -r '.parameters[] | select(.status == "no_boundaries_identified") | "  - \(.name)"' | while read -r line; do
        warn "$line"
    done
    warn "To declare boundaries explicitly, add 'boundary_values' array to parameter-model.json"
fi

if [[ "$BOUNDARY_ALL_COVERED" == "true" ]]; then
    log "All identified boundary values are present in test combinations."
else
    fail "Boundary values missing from test combinations:"
    echo "$BOUNDARY_REPORT" | jq -r '.missing_boundaries[] | "  PARAM: \(.parameter) | MISSING: \(.missing | join(", "))"' | while read -r line; do
        fail "$line"
    done
    BOUNDARY_FAILURES=true
fi

# ── 3. Combination Minimum Threshold ─────────────────────────
echo ""
info "=== 3. Combination Adequacy ==="

# Minimum combinations = max(parameter value count) — ensures at least each value appears once
MIN_EXPECTED=$(jq '[.parameters[].values | length] | max' "$PARAM_FILE" 2>/dev/null || echo 1)

if [[ "$TOTAL_COMBOS" -lt "$MIN_EXPECTED" ]]; then
    fail "Too few combinations: $TOTAL_COMBOS (expected >= $MIN_EXPECTED based on parameter value counts)"
    ADEQUACY_FAILURE=true
else
    log "Combination count adequate: $TOTAL_COMBOS (>= $MIN_EXPECTED)"
    ADEQUACY_FAILURE=false
fi

# ── 4. Print full coverage report ────────────────────────────
echo ""
info "=== Coverage Report Summary ==="
printf "  %-30s %s\n" "Requirements covered:"  "$(jq '(.requirements | length) - (.uncovered_requirements | length)' "$MATRIX_FILE") / $TOTAL_REQS"
printf "  %-30s %s\n" "Boundary values covered:" "$(echo "$BOUNDARY_REPORT" | jq '[.parameters[] | select(.status == "covered")] | length') / $(echo "$BOUNDARY_REPORT" | jq '[.parameters[] | select(.status != "no_boundaries_identified")] | length')"
printf "  %-30s %s\n" "Total combinations:"      "$TOTAL_COMBOS"
printf "  %-30s %s\n" "Total parameters:"        "$TOTAL_PARAMS"
echo ""

# ── Final exit decision ───────────────────────────────────────
HAS_FAILURES=false
[[ "${COVERAGE_FAILURES:-false}" == "true" ]] && HAS_FAILURES=true
[[ "${BOUNDARY_FAILURES:-false}" == "true" ]] && HAS_FAILURES=true
[[ "${ADEQUACY_FAILURE:-false}" == "true" ]]  && HAS_FAILURES=true

if [[ "$HAS_FAILURES" == "true" ]]; then
    echo ""
    fail "=== check-traceability FAILED ==="
    fail "Fix the above issues and re-run the pict-generate gate."
    echo ""
    exit 1
fi

log "=== check-traceability PASSED ==="
log "All requirements are traced and boundary values are present."
echo ""
exit 0
