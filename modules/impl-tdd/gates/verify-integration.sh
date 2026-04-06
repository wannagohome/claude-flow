#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gate: verify-integration
# Catches issues that arise from parallel implementation:
# 1. Unused exports (file exports something nobody imports)
# 2. Missing DI registrations (configurable pattern detection)
# 3. Dead files (created but never imported)
#
# Runs AFTER compile+lint pass, as a pre-gate for code-review.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

PIPELINE_JSON="${1:?Usage: $0 <pipeline.json> <base_dir> <project_root>}"
BASE_DIR="${2:?}"
PROJECT_ROOT="${3:?}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[verify-integration]${NC} $*"; }
warn() { echo -e "${YELLOW}[verify-integration]${NC} $*"; }

FEATURE_SLUG=$(jq -r '.feature_slug' "$PIPELINE_JSON")
REPORT_FILE="$BASE_DIR/.pipeline/integration-issues.json"

mkdir -p "$(dirname "$REPORT_FILE")"

cd "$PROJECT_ROOT"

node - "$FEATURE_SLUG" "$PROJECT_ROOT" "$REPORT_FILE" <<'JSEOF'
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const featureSlug = process.argv[2];
const projectRoot = process.argv[3];
const reportFile = process.argv[4];

// Convert slug to patterns for finding feature files
// e.g. "meal-recording" -> look in src/**/*meal-recording* or *MealRecording*
const pascalCase = featureSlug
  .split('-')
  .map(w => w.charAt(0).toUpperCase() + w.slice(1))
  .join('');
const camelCase = pascalCase.charAt(0).toLowerCase() + pascalCase.slice(1);

const issues = {
  unused_exports: [],
  missing_di: [],
  dead_files: [],
  summary: { total: 0, critical: 0, warning: 0 }
};

// Determine source directories to scan
// Supports common project structures: src/, app/, lib/, packages/
function getSourceDirs() {
  const candidates = ['src', 'app', 'lib', 'packages'];
  return candidates.filter(d => fs.existsSync(path.join(projectRoot, d)));
}

const sourceDirs = getSourceDirs();
const srcGlob = sourceDirs.join(' ');

// Find all TS/TSX files related to this feature
function findFeatureFiles() {
  try {
    const dirs = sourceDirs.join(' ');
    const result = execSync(
      `find ${dirs} -type f \\( -name "*.ts" -o -name "*.tsx" \\) | grep -i "${featureSlug}\\|${pascalCase}\\|${camelCase}" 2>/dev/null || true`,
      { cwd: projectRoot, encoding: 'utf8' }
    );
    return result.trim().split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

// Find all project TS/TSX files (for cross-reference)
function findAllTsFiles() {
  try {
    const dirs = sourceDirs.join(' ');
    const result = execSync(
      `find ${dirs} -type f \\( -name "*.ts" -o -name "*.tsx" \\) 2>/dev/null || true`,
      { cwd: projectRoot, encoding: 'utf8' }
    );
    return result.trim().split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

const featureFiles = findFeatureFiles();
const allFiles = findAllTsFiles();

if (featureFiles.length === 0) {
  console.log('No feature files found -- skipping integration checks');
  fs.writeFileSync(reportFile, JSON.stringify(issues));
  process.exit(0);
}

console.log(`Found ${featureFiles.length} feature files`);

// ── Check 1: Unused exports ──────────────────────────────────
// For each feature file, find exports and check if they're imported elsewhere
for (const file of featureFiles) {
  const filePath = path.join(projectRoot, file);
  if (!fs.existsSync(filePath)) continue;
  const content = fs.readFileSync(filePath, 'utf8');

  // Extract export names
  const exportPattern = /export\s+(?:default\s+)?(?:function|class|const|type|interface|enum)\s+(\w+)/g;
  let match;
  const exports = [];
  while ((match = exportPattern.exec(content)) !== null) {
    exports.push(match[1]);
  }

  // Also catch "export { X, Y }"
  const reExportPattern = /export\s*\{([^}]+)\}/g;
  while ((match = reExportPattern.exec(content)) !== null) {
    match[1].split(',').forEach(name => {
      const trimmed = name.trim().split(/\s+as\s+/)[0].trim();
      if (trimmed) exports.push(trimmed);
    });
  }

  for (const exp of exports) {
    // Search for this export being imported in any file
    let found = false;
    try {
      const searchDirs = sourceDirs.join(' ');
      const grepResult = execSync(
        `grep -rl "import.*${exp}" ${searchDirs} --include="*.ts" --include="*.tsx" 2>/dev/null || true`,
        { cwd: projectRoot, encoding: 'utf8' }
      );
      const importingFiles = grepResult.trim().split('\n').filter(f => f && f !== file);
      found = importingFiles.length > 0;
    } catch {}

    if (!found) {
      // Also check common DI/config files for the export name
      try {
        const configCheck = execSync(
          `grep -rl "${exp}" ${searchDirs} --include="*.ts" --include="*.tsx" 2>/dev/null || true`,
          { cwd: projectRoot, encoding: 'utf8' }
        );
        const configFiles = configCheck.trim().split('\n').filter(f => f && f !== file);
        if (configFiles.length > 0) found = true;
      } catch {}
    }

    if (!found) {
      issues.unused_exports.push({
        file,
        export_name: exp,
        severity: 'warning',
        message: `${exp} is exported but not imported anywhere`
      });
    }
  }
}

// ── Check 2: Missing DI registrations ────────────────────────
// Find classes with DI decorators and check they are registered
// Supports common patterns: @injectable(), @Injectable(), @Service(), etc.
const diPatterns = [
  /@injectable\(\)\s*(?:export\s+)?class\s+(\w+)/g,
  /@Injectable\(\)\s*(?:export\s+)?class\s+(\w+)/g,
  /@Service\(\)\s*(?:export\s+)?class\s+(\w+)/g,
];

// Find DI container files by common names
function findDiContainerFiles() {
  const patterns = ['Container.ts', 'container.ts', 'di.ts', 'providers.ts', 'module.ts'];
  const found = [];
  for (const dir of sourceDirs) {
    try {
      const result = execSync(
        `find ${dir} -type f -name "*.ts" | grep -iE "(container|di-config|providers|module)" 2>/dev/null || true`,
        { cwd: projectRoot, encoding: 'utf8' }
      );
      found.push(...result.trim().split('\n').filter(Boolean));
    } catch {}
  }
  return found;
}

const diContainerFiles = findDiContainerFiles();
let containerContents = '';
for (const cf of diContainerFiles) {
  try {
    containerContents += fs.readFileSync(path.join(projectRoot, cf), 'utf8') + '\n';
  } catch {}
}

for (const file of featureFiles) {
  const filePath = path.join(projectRoot, file);
  if (!fs.existsSync(filePath)) continue;
  const content = fs.readFileSync(filePath, 'utf8');

  for (const pattern of diPatterns) {
    // Reset lastIndex for each file
    pattern.lastIndex = 0;
    let match;
    while ((match = pattern.exec(content)) !== null) {
      const className = match[1];
      const isRegistered = containerContents.includes(className);
      if (!isRegistered) {
        issues.missing_di.push({
          file,
          class_name: className,
          severity: 'critical',
          message: `${className} has a DI decorator but is not registered in any container/provider file`
        });
      }
    }
  }
}

// ── Check 3: Dead files ──────────────────────────────────────
// Feature files that are not imported by any other file
for (const file of featureFiles) {
  // Skip test files, index files, route files, config files
  if (file.includes('__tests__') || file.includes('.test.') || file.includes('.e2e.') || file.includes('.spec.')) continue;
  if (file.endsWith('index.ts') || file.endsWith('index.tsx')) continue;
  if (file.startsWith('app/') || file.startsWith('pages/')) continue;

  const basename = path.basename(file, path.extname(file));

  let isImported = false;
  try {
    // Check if any file imports from this file's path
    const searchDirs = sourceDirs.join(' ');
    const grepResult = execSync(
      `grep -rl "${basename}" ${searchDirs} --include="*.ts" --include="*.tsx" 2>/dev/null || true`,
      { cwd: projectRoot, encoding: 'utf8' }
    );
    const importingFiles = grepResult.trim().split('\n').filter(f => f && f !== file);
    isImported = importingFiles.length > 0;
  } catch {}

  if (!isImported) {
    // Also check DI container files
    if (containerContents.includes(basename)) {
      isImported = true;
    }
  }

  if (!isImported) {
    issues.dead_files.push({
      file,
      severity: 'warning',
      message: `${file} is not imported by any other file`
    });
  }
}

// Summary
issues.summary.total = issues.unused_exports.length + issues.missing_di.length + issues.dead_files.length;
issues.summary.critical = issues.missing_di.length;
issues.summary.warning = issues.unused_exports.length + issues.dead_files.length;

fs.writeFileSync(reportFile, JSON.stringify(issues));
console.log(`Issues: ${issues.missing_di.length} critical (DI), ${issues.unused_exports.length} unused exports, ${issues.dead_files.length} dead files`);
JSEOF

# Print results
log "Report: $REPORT_FILE"
TOTAL=$(jq '.summary.total' "$REPORT_FILE")
CRITICAL=$(jq '.summary.critical' "$REPORT_FILE")

if [[ "$CRITICAL" -gt 0 ]]; then
  warn "Found ${CRITICAL} critical issues (missing DI registrations)"
  jq -r '.missing_di[] | "  ! \(.class_name) in \(.file)"' "$REPORT_FILE"
fi

if [[ "$TOTAL" -gt 0 ]]; then
  log "Total issues: $TOTAL (details in report file)"
else
  log "No integration issues found"
fi

# Always pass — issues are informational for code-review
exit 0
