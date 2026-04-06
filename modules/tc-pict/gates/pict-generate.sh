#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gate: pict-generate
# Converts parameter-model.json -> test-combinations.json via PICT
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

PIPELINE_JSON="${1:?Usage: $0 <pipeline.json> <base_dir> <project_root>}"
BASE_DIR="${2:?}"
PROJECT_ROOT="${3:?}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[pict-generate]${NC} $*"; }
warn() { echo -e "${YELLOW}[pict-generate]${NC} $*"; }
fail() { echo -e "${RED}[pict-generate]${NC} $*" >&2; exit 1; }

INTEG_DIR="$BASE_DIR/test-plan/integration"
PARAM_FILE="$INTEG_DIR/parameter-model.json"
PICT_FILE="$INTEG_DIR/parameter-model.pict"
COMBINATIONS_FILE="$INTEG_DIR/test-combinations.json"
TRACEABILITY_FILE="$INTEG_DIR/traceability-matrix.json"

# ── Validate inputs ──────────────────────────────────────────
[[ -f "$PIPELINE_JSON" ]] || fail "pipeline.json not found: $PIPELINE_JSON"
[[ -f "$PARAM_FILE" ]]    || fail "parameter-model.json not found: $PARAM_FILE"

command -v jq >/dev/null 2>&1      || fail "jq is required"
command -v node >/dev/null 2>&1    || fail "node is required for fallback"
command -v python3 >/dev/null 2>&1 || fail "python3 is required for PICT model conversion"

log "Reading parameter-model.json..."

# ── Validate parameter model structure ───────────────────────
PARAM_COUNT=$(jq '.parameters | length' "$PARAM_FILE" 2>/dev/null || echo 0)
[[ "$PARAM_COUNT" -gt 0 ]] || fail "parameter-model.json has no parameters"
log "Found $PARAM_COUNT parameters"

# ── Convert to PICT format ────────────────────────────────────
log "Converting to PICT model format..."

# PICT doesn't handle non-ASCII characters well — encode to ASCII aliases, run PICT, then decode back.
# Generates: parameter-model.pict (ASCII) + parameter-model.pict.map.json (reverse mapping)
python3 - "$PARAM_FILE" "$PICT_FILE" <<'PYEOF'
import json, sys

param_file = sys.argv[1]
pict_file  = sys.argv[2]
map_file   = pict_file + ".map.json"

with open(param_file) as f:
    model = json.load(f)

# Build bidirectional mapping: original -> ASCII alias
to_ascii = {}   # "original" -> "P0_V1"
to_original = {}  # "P0_V1" -> "original"

lines = []
for pi, param in enumerate(model.get("parameters", [])):
    pkey = f"P{pi}"
    to_ascii[param["name"]] = pkey
    to_original[pkey] = param["name"]

    aliases = []
    for vi, val in enumerate(param["values"]):
        vkey = f"{pkey}V{vi}"
        sval = str(val)
        to_ascii[sval] = vkey
        to_original[vkey] = sval
        aliases.append(vkey)

    lines.append(f"{pkey}: {', '.join(aliases)}")

# Convert constraints
constraints = model.get("constraints", [])
if constraints:
    lines.append("")
    for c in constraints:
        # Replace tokens with ASCII aliases (longest match first)
        converted = c
        for orig, asc in sorted(to_ascii.items(), key=lambda x: -len(x[0])):
            converted = converted.replace(f'"{orig}"', f'"{asc}"')
            converted = converted.replace(f'[{orig}]', f'[{asc}]')
        lines.append(converted)

with open(pict_file, "w") as f:
    f.write("\n".join(lines) + "\n")

with open(map_file, "w") as f:
    json.dump(to_original, f, ensure_ascii=False)

print(f"Written {len(model.get('parameters', []))} parameters (ASCII-encoded) to {pict_file}")
PYEOF

log "PICT model written to $PICT_FILE"

# ── Run PICT or fallback ──────────────────────────────────────
RAW_COMBINATIONS=""

if ! command -v pict >/dev/null 2>&1; then
    log "pict not found — installing via Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        brew install pict 2>&1 || fail "Failed to install pict via Homebrew"
        log "pict installed successfully"
    else
        fail "pict not found and Homebrew not available. Install pict manually: https://github.com/microsoft/pict"
    fi
fi

if command -v pict >/dev/null 2>&1; then
    log "Running PICT..."
    PICT_STDERR=$(mktemp /tmp/pict-stderr-XXXXXX)
    RAW_COMBINATIONS=$(pict "$PICT_FILE" /o:2 2>"$PICT_STDERR") || {
        PICT_ERR=$(cat "$PICT_STDERR")
        rm -f "$PICT_STDERR"
        fail "pict execution failed: $PICT_ERR"
    }
    rm -f "$PICT_STDERR"
    log "PICT generated combinations successfully"
    GENERATION_METHOD="pict"
else
    fail "pict installation failed"
fi

# ── Parse raw TSV output into JSON ────────────────────────────
log "Parsing combinations into JSON..."

# Write raw combinations to temp file (avoids shell injection from heredoc interpolation)
RAW_COMBOS_FILE=$(mktemp /tmp/pict-raw-XXXXXX)
echo "$RAW_COMBINATIONS" > "$RAW_COMBOS_FILE"

# Debug: show PICT output line count
RAW_LINE_COUNT=$(wc -l < "$RAW_COMBOS_FILE" | tr -d ' ')
log "PICT raw output: ${RAW_LINE_COUNT} lines"
if [[ "$RAW_LINE_COUNT" -lt 2 ]]; then
    warn "PICT output:"
    cat "$RAW_COMBOS_FILE" >&2
fi

node - "$PARAM_FILE" "$COMBINATIONS_FILE" "$GENERATION_METHOD" "$RAW_COMBOS_FILE" "$PICT_FILE.map.json" <<'JSEOF'
const fs = require('fs');
const model = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const outFile = process.argv[3];
const method  = process.argv[4];
const rawCombosFile = process.argv[5];
const mapFile = process.argv[6];
const params  = model.parameters || [];

// Load ASCII -> original reverse mapping
const toOriginal = fs.existsSync(mapFile) ? JSON.parse(fs.readFileSync(mapFile, 'utf8')) : {};
const decode = (s) => toOriginal[s] || s;

const rawLines = fs.readFileSync(rawCombosFile, 'utf8').trim().split('\n');
if (rawLines.length < 2) {
    console.error('No combination rows found in output');
    process.exit(1);
}

// First line is header (tab-separated parameter names) — decode back to original
const headers = rawLines[0].split('\t').map(h => decode(h.trim()));
const combinations = [];

for (let i = 1; i < rawLines.length; i++) {
    const line = rawLines[i].trim();
    if (!line) continue;
    const values = line.split('\t').map(v => decode(v.trim()));
    const combo = {};
    headers.forEach((h, idx) => { combo[h] = values[idx] ?? ''; });
    combinations.push({ id: `TC-${String(i).padStart(3, '0')}`, parameters: combo });
}

const output = {
    generated_at: new Date().toISOString(),
    generation_method: method,
    parameter_count: params.length,
    combination_count: combinations.length,
    combinations
};

fs.writeFileSync(outFile, JSON.stringify(output));
console.log(`Written ${combinations.length} combinations to ${outFile}`);
JSEOF

rm -f "$RAW_COMBOS_FILE"

COMBO_COUNT=$(jq '.combination_count' "$COMBINATIONS_FILE")
log "Generated $COMBO_COUNT test combinations ($GENERATION_METHOD)"

# ── Generate traceability matrix ──────────────────────────────
log "Generating traceability-matrix.json..."

jq -n \
    --slurpfile params "$PARAM_FILE" \
    --slurpfile combos "$COMBINATIONS_FILE" \
    '
    {
        generated_at: now | todate,
        requirements: (
            $params[0].requirements // [] |
            map({
                id: .id,
                description: (.description // ""),
                covering_parameters: (.parameters // []),
                covering_combinations: (
                    .parameters as $rp |
                    [$combos[0].combinations[] |
                        select(
                            .parameters as $cp |
                            ($rp | all(. as $p | $cp | has($p)))
                        ) | .id
                    ]
                )
            })
        ),
        uncovered_requirements: (
            $params[0].requirements // [] |
            map(select(
                .parameters as $rp |
                [$combos[0].combinations[] |
                    select(
                        .parameters as $cp |
                        ($rp | all(. as $p | $cp | has($p)))
                    )
                ] | length == 0
            )) | map(.id)
        )
    }
    ' > "$TRACEABILITY_FILE"

UNCOVERED=$(jq '.uncovered_requirements | length' "$TRACEABILITY_FILE")
TOTAL_REQS=$(jq '.requirements | length' "$TRACEABILITY_FILE")

log "Traceability matrix: $TOTAL_REQS requirements, $UNCOVERED uncovered"

if [[ "$UNCOVERED" -gt 0 ]]; then
    warn "Uncovered requirements:"
    jq -r '.uncovered_requirements[]' "$TRACEABILITY_FILE" | while read -r rid; do
        warn "  - $rid"
    done
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
log "=== pict-generate summary ==="
log "  Parameter model : $PARAM_FILE"
log "  PICT model      : $PICT_FILE"
log "  Combinations    : $COMBINATIONS_FILE ($COMBO_COUNT rows, method: $GENERATION_METHOD)"
log "  Traceability    : $TRACEABILITY_FILE ($TOTAL_REQS reqs, $UNCOVERED uncovered)"

exit 0
