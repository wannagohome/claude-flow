#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gate: generate-review-checklist
# Extracts requirements from FINALIZED spec and test cases from
# FINALIZED test plans to produce a checklist for code-review.
#
# Purpose: The code reviewer uses this checklist to verify each
# requirement is implemented and each TC has a corresponding test.
# This makes code review deterministic — the reviewer checks items
# one by one instead of freely exploring.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

PIPELINE_JSON="${1:?Usage: $0 <pipeline.json> <base_dir> <project_root>}"
BASE_DIR="${2:?}"
PROJECT_ROOT="${3:?}"

CHECKLIST_FILE="$BASE_DIR/.pipeline/code-review-checklist.json"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[review-checklist]${NC} $*"; }
fail() { echo -e "${RED}[review-checklist]${NC} $*" >&2; exit 1; }

mkdir -p "$(dirname "$CHECKLIST_FILE")"

node - "$BASE_DIR" "$CHECKLIST_FILE" <<'JSEOF'
const fs = require('fs');
const path = require('path');

const baseDir = process.argv[2];
const outFile = process.argv[3];
const specDir = path.join(baseDir, 'spec');
const integDir = path.join(baseDir, 'test-plan', 'integration');
const e2eDir = path.join(baseDir, 'test-plan', 'e2e');

const checklist = {
  generated_at: new Date().toISOString(),
  purpose: 'Code reviewer checks each item against implementation. Pass/fail per item.',
  spec_requirements: [],
  integration_test_cases: [],
  e2e_scenarios: [],
  summary: {}
};

// ── Extract requirements from spec ────────────────────────────
// Read all spec .md files and extract structured requirements
function readDir(dir) {
  if (!fs.existsSync(dir)) return [];
  const files = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isFile() && e.name.endsWith('.md')) {
      files.push(path.join(dir, e.name));
    } else if (e.isDirectory()) {
      for (const s of fs.readdirSync(path.join(dir, e.name), { withFileTypes: true })) {
        if (s.isFile() && s.name.endsWith('.md')) {
          files.push(path.join(dir, e.name, s.name));
        }
      }
    }
  }
  return files;
}

for (const filePath of readDir(specDir)) {
  const content = fs.readFileSync(filePath, 'utf8');
  const fileName = path.relative(baseDir, filePath);
  const lines = content.split('\n');

  // Strategy: extract every heading that looks like a requirement
  // and the text immediately following it as the description
  let currentHeading = null;
  let currentDesc = [];

  for (let i = 0; i < lines.length; i++) {
    const headingMatch = lines[i].match(/^(#{2,4})\s+(.+)/);
    if (headingMatch) {
      // Save previous
      if (currentHeading) {
        checklist.spec_requirements.push({
          id: currentHeading.id || `${fileName}:L${currentHeading.line}`,
          title: currentHeading.title,
          file: fileName,
          line: currentHeading.line,
          description: currentDesc.join(' ').trim().substring(0, 300),
          review_question: `Is the "${currentHeading.title}" requirement implemented in the code?`
        });
      }
      // Start new heading
      const title = headingMatch[2].trim();
      const idMatch = title.match(/\b(REQ|FR|NFR|UC|EC|AC)-\d+\b/);
      currentHeading = {
        title,
        id: idMatch ? idMatch[0] : null,
        line: i + 1
      };
      currentDesc = [];
    } else if (currentHeading && lines[i].trim()) {
      currentDesc.push(lines[i].trim());
    }
  }
  // Don't forget the last one
  if (currentHeading) {
    checklist.spec_requirements.push({
      id: currentHeading.id || `${fileName}:L${currentHeading.line}`,
      title: currentHeading.title,
      file: fileName,
      line: currentHeading.line,
      description: currentDesc.join(' ').trim().substring(0, 300),
      review_question: `Is the "${currentHeading.title}" requirement implemented in the code?`
    });
  }
}

// ── Extract TCs from integration test plan ────────────────────
const integPlanPath = path.join(integDir, 'test-plan-integration.md');
if (fs.existsSync(integPlanPath)) {
  const content = fs.readFileSync(integPlanPath, 'utf8');
  // Extract TC-NNN or IT-NNN patterns with surrounding context
  const tcPattern = /\b(TC|IT)-(\d+)\b/g;
  let match;
  const seen = new Set();
  while ((match = tcPattern.exec(content)) !== null) {
    const tcId = match[0];
    if (seen.has(tcId)) continue;
    seen.add(tcId);

    // Get the line containing this TC
    const beforeMatch = content.substring(0, match.index);
    const lineNum = (beforeMatch.match(/\n/g) || []).length + 1;
    const lines = content.split('\n');
    const line = lines[lineNum - 1] || '';

    checklist.integration_test_cases.push({
      id: tcId,
      context: line.trim().substring(0, 200),
      review_question: `Does an integration test exist for ${tcId}?`
    });
  }
}

// Also try reading test-combinations.json for PICT-generated TCs
const combPath = path.join(integDir, 'test-combinations.json');
if (fs.existsSync(combPath)) {
  try {
    const comb = JSON.parse(fs.readFileSync(combPath, 'utf8'));
    if (comb.combinations && checklist.integration_test_cases.length === 0) {
      // If no TCs extracted from plan, use PICT combinations directly
      comb.combinations.forEach((combo, idx) => {
        const desc = typeof combo === 'object'
          ? Object.entries(combo).map(([k, v]) => `${k}=${v}`).join(', ')
          : String(combo);
        checklist.integration_test_cases.push({
          id: `PICT-${String(idx + 1).padStart(3, '0')}`,
          context: desc.substring(0, 200),
          review_question: `Does a test exist for the combination [${desc.substring(0, 80)}]?`
        });
      });
    }
  } catch {}
}

// ── Extract scenarios from E2E test plan ──────────────────────
const flowsPath = path.join(e2eDir, 'user-flows.json');
if (fs.existsSync(flowsPath)) {
  try {
    const flows = JSON.parse(fs.readFileSync(flowsPath, 'utf8'));
    for (const scenario of (flows.scenarios || [])) {
      checklist.e2e_scenarios.push({
        id: scenario.id || scenario.name,
        name: scenario.name,
        priority: scenario.priority || 'medium',
        review_question: `Does an E2E test flow exist for scenario "${scenario.name}"?`
      });
    }
  } catch {}
}

// Fallback: parse test-plan-e2e.md for scenario headers
if (checklist.e2e_scenarios.length === 0) {
  const e2ePlanPath = path.join(e2eDir, 'test-plan-e2e.md');
  if (fs.existsSync(e2ePlanPath)) {
    const content = fs.readFileSync(e2ePlanPath, 'utf8');
    const scenarioPattern = /^###?\s+(S-\d+|Scenario\s+\d+)[:\s]+(.+)/gm;
    let m;
    while ((m = scenarioPattern.exec(content)) !== null) {
      checklist.e2e_scenarios.push({
        id: m[1],
        name: m[2].trim(),
        review_question: `Does an E2E test exist for scenario "${m[2].trim()}"?`
      });
    }
  }
}

// ── Summary ───────────────────────────────────────────────────
checklist.summary = {
  spec_requirements: checklist.spec_requirements.length,
  integration_tcs: checklist.integration_test_cases.length,
  e2e_scenarios: checklist.e2e_scenarios.length,
  total_items: checklist.spec_requirements.length
    + checklist.integration_test_cases.length
    + checklist.e2e_scenarios.length
};

fs.writeFileSync(outFile, JSON.stringify(checklist));
console.log(`Checklist: ${checklist.summary.spec_requirements} requirements, ${checklist.summary.integration_tcs} TCs, ${checklist.summary.e2e_scenarios} scenarios = ${checklist.summary.total_items} items`);
JSEOF

log "Code review checklist: $CHECKLIST_FILE"
jq -r '.summary | "  Requirements: \(.spec_requirements)\n  Integration TCs: \(.integration_tcs)\n  E2E Scenarios: \(.e2e_scenarios)\n  Total: \(.total_items)"' "$CHECKLIST_FILE"

exit 0
