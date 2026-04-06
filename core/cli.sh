#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/cli.sh — CLI Interface
# ═══════════════════════════════════════════════════════════════
# Main entry point for claude-flow. Sources all core modules,
# checks prerequisites, provides CLI commands for pipeline
# management (setup, init, run, continue, review, edit, status).
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
DIM='\033[2m'; NC='\033[0m'

# ── Paths ──
FLOW_HOME="${FLOW_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ── Source Core Modules ──
source "$FLOW_HOME/core/state.sh"
source "$FLOW_HOME/core/model.sh"
source "$FLOW_HOME/core/prompt.sh"
source "$FLOW_HOME/core/review.sh"
source "$FLOW_HOME/core/engine.sh"
source "$FLOW_HOME/core/loader.sh"

# ── Prerequisites ──
command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq is required. Install: brew install jq${NC}"; exit 1; }
command -v claude >/dev/null 2>&1 || { echo -e "${RED}claude CLI is required. See: https://docs.anthropic.com/claude-code${NC}"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo -e "${RED}yq is required. Install: brew install yq${NC}"; exit 1; }

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

find_flow_json() {
  local feature="$1"
  local slug
  slug=$(echo "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  local found
  found=$(find "$PROJECT_ROOT/docs/requirements" -maxdepth 1 -name "*-${slug}" -type d 2>/dev/null | sort -r | head -1)
  if [[ -z "$found" || ! -f "$found/flow.json" ]]; then
    echo ""
    return
  fi
  echo "$found/flow.json"
}

# ═══════════════════════════════════════════════════════════════
# CLI Commands
# ═══════════════════════════════════════════════════════════════

usage() {
  echo -e "${BOLD}claude-flow — Multi-Session Pipeline Orchestrator${NC}"
  echo -e "${DIM}Stateless shell orchestrator that runs claude -p sessions with fresh context per stage.${NC}"
  echo -e "${DIM}Writer/Reviewer separation으로 context contamination을 방지합니다.${NC}"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo ""
  echo -e "  ${CYAN}setup${NC}                        프로젝트 초기 설정 (.claude/flow.yaml 생성)"
  echo ""
  echo -e "  ${CYAN}init${NC} <feature> [options]     새 파이프라인 초기화 (docs/requirements/ 하위에 생성)"
  echo -e "       --prd <url>              PRD 문서 URL (Confluence 등)"
  echo -e "       --figma <url>            Figma 디자인 URL"
  echo -e "       --web <path>             WebView 웹 워크스페이스 경로"
  echo -e "       --skip-design            Design Phase 건너뛰기"
  echo ""
  echo -e "  ${CYAN}run${NC} <feature> [options]      파이프라인 실행 (pending 스테이지부터 순차 진행)"
  echo -e "       --stage <stage>          특정 스테이지만 단독 실행"
  echo ""
  echo -e "  ${CYAN}<feature> --edit${NC} \"prompt\"     대기 중인 산출물을 AI로 수정"
  echo ""
  echo -e "  ${CYAN}<feature> --review${NC}           스펙 수정 후 review를 다시 실행 (audit 모드)"
  echo ""
  echo -e "  ${CYAN}<feature> --continue${NC}         대기 중인 manual gate를 완료하고 파이프라인 재개"
  echo ""
  echo -e "  ${CYAN}<feature> --force-continue${NC}   critical findings를 무시하고 강제 진행"
  echo ""
  echo -e "  ${CYAN}status${NC} <feature>             파이프라인 진행 현황 조회"
  echo ""
  echo -e "  ${CYAN}stages${NC} [feature]             스테이지 목록 및 의존관계 출력"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  claude-flow setup"
  echo "  claude-flow init meal-recording --prd 'https://...' --figma 'https://...'"
  echo "  claude-flow run meal-recording"
  echo "  claude-flow run meal-recording --stage spec-write"
  echo "  claude-flow status meal-recording"
  echo "  claude-flow meal-recording --edit '에러 상태 스펙 보완해줘'"
  echo "  claude-flow meal-recording --review"
  echo "  claude-flow meal-recording --continue"
  echo "  claude-flow stages meal-recording"
  echo ""
  echo -e "${BOLD}Prerequisites:${NC} jq, claude CLI, yq"
}

# ── Setup: interactive flow.yaml + conventions.md creation ──

cmd_setup() {
  local flow_yaml="${PROJECT_ROOT}/.claude/flow.yaml"

  if [[ -f "$flow_yaml" ]]; then
    echo -e "${YELLOW}flow.yaml already exists: ${flow_yaml}${NC}"
    echo -e "Edit it directly or delete and re-run setup."
    return 1
  fi

  mkdir -p "${PROJECT_ROOT}/.claude/flow"

  echo -e "${BOLD}claude-flow setup${NC}"
  echo ""

  # Preset selection
  echo -e "${CYAN}Available presets:${NC}"
  echo -e "  1. ${BOLD}full-tdd${NC}   — Full pipeline (spec -> test plan -> design -> implement -> verify)"
  echo -e "  2. ${BOLD}impl-only${NC}  — Implementation + verification only"
  echo -e "  3. ${BOLD}spec-only${NC}  — Spec + test plan only"
  echo -e "  4. ${BOLD}custom${NC}     — Start from scratch"
  echo ""
  read -rp "Select preset [1-4, default: 1]: " preset_choice
  preset_choice="${preset_choice:-1}"

  local preset_name=""
  case "$preset_choice" in
    1) preset_name="full-tdd" ;;
    2) preset_name="impl-only" ;;
    3) preset_name="spec-only" ;;
    4) preset_name="" ;;
    *) preset_name="full-tdd" ;;
  esac

  # Test commands
  read -rp "Unit test command [default: npm test]: " test_cmd
  test_cmd="${test_cmd:-npm test}"

  read -rp "E2E test command [leave empty to skip]: " e2e_cmd

  # Generate flow.yaml
  {
    if [[ -n "$preset_name" ]]; then
      echo "extends: ${preset_name}"
      echo ""
    fi
    echo "project:"
    echo "  conventions: ./flow/conventions.md"
    echo ""
    echo "providers:"
    echo "  figma:"
    echo "    enabled: false"
    echo "  confluence:"
    echo "    enabled: false"
    echo ""
    echo "models:"
    echo "  write: claude-opus-4-6"
    echo "  review: claude-sonnet-4-6"
    echo "  audit: claude-opus-4-6"
    echo "  escalation:"
    echo "    model: claude-opus-4-6"
    echo "    after_round: 5"
    echo ""
    echo "review:"
    echo "  max_rounds: 3"
    echo ""
    echo "test:"
    echo "  unit:"
    echo "    command: \"${test_cmd}\""
    if [[ -n "$e2e_cmd" ]]; then
      echo "  e2e:"
      echo "    command: \"${e2e_cmd}\""
    fi
  } > "$flow_yaml"

  # Create empty conventions.md
  local conventions="${PROJECT_ROOT}/.claude/flow/conventions.md"
  if [[ ! -f "$conventions" ]]; then
    cat > "$conventions" << 'CONVEOF'
# Project Conventions

<!-- Describe your project's coding conventions here.
     This file is injected into every pipeline session as Layer 2.
     Include: naming conventions, error handling patterns, import style,
     testing patterns, framework-specific rules, etc. -->

CONVEOF
  fi

  echo ""
  echo -e "${GREEN}✓ Setup complete${NC}"
  echo -e "  ${DIM}${flow_yaml}${NC}"
  echo -e "  ${DIM}${conventions}${NC}"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo -e "  1. Edit ${CYAN}.claude/flow.yaml${NC} to customize your pipeline"
  echo -e "  2. Write conventions in ${CYAN}.claude/flow/conventions.md${NC}"
  echo -e "  3. Run ${BOLD}claude-flow init <feature>${NC} to start a pipeline"
}

# ── Init: create flow.json from flow.yaml ──

cmd_init() {
  if [[ $# -lt 1 ]]; then
    echo -e "${RED}Usage: claude-flow init <feature> [options]${NC}"
    return 1
  fi

  local feature="$1"; shift
  local prd_url="" figma_url="" web_workspace="" skip_design=false
  local extra_flags=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prd)          prd_url="$2"; shift 2 ;;
      --figma)        figma_url="$2"; shift 2 ;;
      --web)          web_workspace="$2"; shift 2 ;;
      --skip-design)  skip_design=true; extra_flags+=("--skip-design"); shift ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Find flow.yaml
  local flow_yaml
  flow_yaml=$(find_flow_yaml)
  if [[ -z "$flow_yaml" ]]; then
    echo -e "${RED}flow.yaml not found. Run 'claude-flow setup' first.${NC}"
    return 1
  fi

  local slug date base_dir flow_json_path
  slug=$(echo "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  date=$(date +%Y-%m-%d)
  base_dir="docs/requirements/${date}-${slug}"
  flow_json_path="${PROJECT_ROOT}/${base_dir}/flow.json"

  if [[ -f "$flow_json_path" ]]; then
    echo -e "${YELLOW}Pipeline already exists: ${flow_json_path}${NC}"
    echo "Use 'claude-flow run ${feature}' to continue."
    return 1
  fi

  # Create directory structure
  mkdir -p "${PROJECT_ROOT}/${base_dir}/spec"
  mkdir -p "${PROJECT_ROOT}/${base_dir}/test-plan/integration"
  mkdir -p "${PROJECT_ROOT}/${base_dir}/test-plan/e2e"
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  # Generate flow.json via loader
  generate_flow_json "$feature" "$base_dir" "$flow_yaml" "$flow_json_path" ${extra_flags[@]+"${extra_flags[@]}"}

  # Store CLI-provided config values in flow.json
  if [[ -n "$figma_url" ]]; then
    update_json "$flow_json_path" ".config.providers.figma.enabled = true | .config.providers.figma.config.figma_url = \"${figma_url}\""
  fi
  if [[ -n "$prd_url" ]]; then
    update_json "$flow_json_path" ".config.providers.confluence.enabled = true | .config.providers.confluence.config.prd_url = \"${prd_url}\""
  fi
  if [[ -n "$web_workspace" ]]; then
    update_json "$flow_json_path" ".config.web_workspace = \"${web_workspace}\""
  fi

  # Create requirements input file
  cat > "${PROJECT_ROOT}/${base_dir}/spec/requirements-input.md" << 'REQEOF'
# 요구사항 입력

이 파일에 구현하고자 하는 기능의 요구사항을 작성하세요.
spec-write 세션이 이 파일을 기반으로 스펙 문서를 생성합니다.

## 기능 설명

<!-- 구현하고자 하는 기능을 자유롭게 설명하세요 -->


## 참고 자료 (선택)

<!-- Confluence, Figma, 기타 링크가 있으면 여기에 -->


## 추가 요구사항 (선택)

<!-- 특별히 포함해야 할 조건, 제약, 비즈니스 규칙 등 -->

REQEOF

  echo -e "${GREEN}✓ Pipeline initialized${NC}"
  echo -e "  ${DIM}${flow_json_path}${NC}"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo -e "  1. 요구사항 작성: ${CYAN}${base_dir}/spec/requirements-input.md${NC}"
  echo -e "  2. 파이프라인 실행: ${BOLD}claude-flow run ${feature}${NC}"
}

# ── Run: execute pipeline ──

cmd_run() {
  if [[ $# -lt 1 ]]; then
    echo -e "${RED}Usage: claude-flow run <feature> [--stage <stage>]${NC}"
    return 1
  fi

  local feature="$1"; shift
  local target_stage=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stage) target_stage="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  local flow_json
  flow_json=$(find_flow_json "$feature")
  if [[ -z "$flow_json" ]]; then
    echo -e "${RED}Pipeline not found for: ${feature}${NC}"
    echo "Initialize first: claude-flow init ${feature}"
    return 1
  fi

  if [[ -n "$target_stage" ]]; then
    # Run specific stage
    echo -e "${BLUE}▶ Running specific stage: ${target_stage}${NC}"
    set_status "$flow_json" "$target_stage" "pending"
    run_single_stage "$flow_json" "$target_stage"
  else
    run_pipeline "$flow_json"
  fi
}

# ── Continue: complete manual gates, reset failures, resume ──

cmd_continue() {
  local feature="$1"
  local force="${2:-false}"
  local flow_json
  flow_json=$(find_flow_json "$feature")
  if [[ -z "$flow_json" ]]; then
    echo -e "${RED}Pipeline not found for: ${feature}${NC}"
    return 1
  fi

  # Reset failed stages and complete waiting gates
  local found_actionable=false
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")

    if [[ "$status" == "failed" ]]; then
      set_status "$flow_json" "$stage" "pending"
      echo -e "${BLUE}↻ Reset failed stage: ${stage}${NC}"
      found_actionable=true
      break
    fi

    if [[ "$status" == "interrupted" || "$status" == "rate_limited" ]]; then
      set_status "$flow_json" "$stage" "pending"
      echo -e "${BLUE}↻ Reset ${status} stage: ${stage}${NC}"
      found_actionable=true
      break
    fi

    if [[ "$status" == "running" ]]; then
      echo -e "${BLUE}▶ Resuming stage: ${stage}${NC}"
      run_single_stage "$flow_json" "$stage"
      found_actionable=true
      break
    fi

    if [[ "$status" == "waiting" ]]; then
      # Check for critical findings in review reports
      if [[ "$force" != "true" ]]; then
        local base_dir
        base_dir=$(read_json "$flow_json" ".base_dir")

        # Look for review reports
        for report in \
          "${PROJECT_ROOT}/${base_dir}/spec/review-report.md" \
          "${PROJECT_ROOT}/${base_dir}/test-plan/review-report.md"; do
          if [[ -f "$report" ]]; then
            local critical_count
            critical_count=$(grep -ci '|\s*critical\s*|' "$report" 2>/dev/null || true)
            critical_count="${critical_count:-0}"
            if [[ "$critical_count" -gt 0 ]]; then
              echo -e "${RED}⚠ Critical findings ${critical_count}건이 남아있습니다.${NC}"
              echo -e "${DIM}  Report: ${report}${NC}"
              grep -i '|\s*critical\s*|' "$report" | head -5
              echo ""
              echo -e "  ${BOLD}1. Edit${NC}:           claude-flow ${feature} --edit \"수정 요청\""
              echo -e "  ${BOLD}2. Force continue${NC}: claude-flow ${feature} --force-continue"
              echo -e "     ${DIM}(critical findings를 무시하고 진행)${NC}"
              return 1
            fi
          fi
        done
      fi

      set_status "$flow_json" "$stage" "complete"
      echo -e "${GREEN}✓ Manual gate completed: ${stage}${NC}"
      found_actionable=true
    fi
  done <<< "$(get_stage_order "$flow_json")"

  if [[ "$found_actionable" == "false" ]]; then
    # Check if there are pending stages ready to run
    local ready_stages
    ready_stages=$(get_ready_stages "$flow_json")
    if [[ -n "$ready_stages" ]]; then
      echo -e "${BLUE}▶ 다음 단계 실행: ${ready_stages}${NC}"
    else
      echo -e "${YELLOW}재개할 대상이 없습니다.${NC}"
      show_status "$flow_json"
      return 0
    fi
  fi

  # Continue pipeline execution
  run_pipeline "$flow_json"
}

# ── Review: re-run review on updated spec ──

cmd_review() {
  local feature="$1"
  local flow_json
  flow_json=$(find_flow_json "$feature")
  if [[ -z "$flow_json" ]]; then
    echo -e "${RED}Pipeline not found for: ${feature}${NC}"
    return 1
  fi

  # Find a waiting manual gate to determine which review to re-run
  local waiting_gate=""
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")
    if [[ "$status" == "waiting" ]]; then
      waiting_gate="$stage"
      break
    fi
  done <<< "$(get_stage_order "$flow_json")"

  if [[ -z "$waiting_gate" ]]; then
    echo -e "${RED}--review is only available when a manual gate is waiting.${NC}"
    return 1
  fi

  # Find the review stage that precedes this manual gate (its dependency)
  local review_stage
  review_stage=$(read_json "$flow_json" ".stages.\"$waiting_gate\".deps[0] // \"\"")

  if [[ -z "$review_stage" ]]; then
    echo -e "${RED}Could not determine review stage for ${waiting_gate}${NC}"
    return 1
  fi

  # Re-run the review stage as audit (doesn't change manual gate status)
  echo -e "${BLUE}▶ Re-running ${review_stage} on updated content...${NC}"
  set_status "$flow_json" "$review_stage" "pending"
  run_audit_stage "$flow_json" "$review_stage"

  # Show guidance after review completes
  echo ""
  echo -e "${YELLOW}${BOLD}⏸  Review complete. Options:${NC}"
  echo -e "   ${BOLD}1. Edit${NC}:      claude-flow ${feature} --edit \"수정 요청\""
  echo -e "   ${BOLD}2. Re-review${NC}: claude-flow ${feature} --review"
  echo -e "   ${BOLD}3. Continue${NC}:  claude-flow ${feature} --continue"
  echo ""
}

# ── Edit: AI-assisted artifact modification ──

cmd_edit() {
  local feature="$1"; shift
  local edit_prompt="$*"

  if [[ -z "$edit_prompt" ]]; then
    echo -e "${RED}수정 요청을 입력하세요.${NC}"
    echo -e "Usage: claude-flow ${feature} --edit \"수정할 내용\""
    return 1
  fi

  local flow_json
  flow_json=$(find_flow_json "$feature")
  if [[ -z "$flow_json" ]]; then
    echo -e "${RED}Pipeline not found for: ${feature}${NC}"
    return 1
  fi

  # Find a waiting or max_exceeded stage
  local waiting_stage=""
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")
    if [[ "$status" == "waiting" || "$status" == "max_exceeded" ]]; then
      waiting_stage="$stage"
      break
    fi
  done <<< "$(get_stage_order "$flow_json")"

  if [[ -z "$waiting_stage" ]]; then
    echo -e "${RED}수정 가능한 대기 중인 스테이지가 없습니다.${NC}"
    show_status "$flow_json"
    return 1
  fi

  local base_dir feature_name
  base_dir=$(read_json "$flow_json" ".base_dir")
  feature_name=$(read_json "$flow_json" ".feature")

  # Determine target directory based on phase
  local phase
  phase=$(get_stage_phase "$flow_json" "$waiting_stage")
  local edit_target
  case "$phase" in
    spec)          edit_target="${PROJECT_ROOT}/${base_dir}/spec" ;;
    test-plan|tc*) edit_target="${PROJECT_ROOT}/${base_dir}/test-plan" ;;
    *)             edit_target="${PROJECT_ROOT}/${base_dir}" ;;
  esac

  # Find review report if it exists
  local review_report_section="리뷰 리포트가 없습니다."
  for report in \
    "${PROJECT_ROOT}/${base_dir}/spec/review-report.md" \
    "${PROJECT_ROOT}/${base_dir}/test-plan/review-report.md"; do
    if [[ -f "$report" ]]; then
      review_report_section="파일: ${report}
아래는 리뷰 리포트 내용입니다. \"리뷰 내용대로 수정\", \"F-001 수정\" 같은 요청 시 참고하세요.

$(cat "$report")"
      break
    fi
  done

  echo -e "${CYAN}═══ Manual Edit (${waiting_stage}) ═══${NC}"
  echo -e "${DIM}  Target: ${edit_target}${NC}"
  echo -e "${DIM}  Request: ${edit_prompt}${NC}"
  echo ""

  # Assemble edit prompt (Layer 1 + Layer 2 + edit-specific body)
  local layer1=""
  if [[ -f "$FLOW_HOME/protocols/session-context.md" ]]; then
    layer1=$(cat "$FLOW_HOME/protocols/session-context.md")
  fi

  local layer2=""
  local conventions_path
  conventions_path=$(read_json "$flow_json" '.config.conventions_path // ""')
  if [[ -n "$conventions_path" && -f "$conventions_path" ]]; then
    layer2=$(cat "$conventions_path")
  fi

  # Check for manual-edit prompt (project override -> built-in)
  local edit_body=""
  local edit_prompt_file="${PROJECT_ROOT}/.claude/flow/prompts/manual-edit.md"
  if [[ ! -f "$edit_prompt_file" ]]; then
    edit_prompt_file="${FLOW_HOME}/protocols/manual-edit.md"
  fi
  if [[ -f "$edit_prompt_file" ]]; then
    edit_body=$(cat "$edit_prompt_file")
  else
    # Inline fallback
    edit_body="# Manual Edit

Feature: {FEATURE}
Target directory: {EDIT_TARGET}

## User Request

{EDIT_PROMPT}

## Review Report

{REVIEW_REPORT_SECTION}

## Instructions

사용자의 수정 요청을 정확히 반영하세요.
기존 산출물의 구조와 품질을 유지하면서 요청된 변경만 수행하세요."
  fi

  local prompt="${layer1}

---

## Project Conventions

${layer2}

---

${edit_body}"

  prompt="${prompt//\{FEATURE\}/${feature_name}}"
  prompt="${prompt//\{EDIT_TARGET\}/${edit_target}}"
  prompt="${prompt//\{EDIT_PROMPT\}/${edit_prompt}}"
  prompt="${prompt//\{BASE_DIR\}/${PROJECT_ROOT}/${base_dir}}"
  prompt="${prompt//\{REVIEW_REPORT_SECTION\}/${review_report_section}}"

  run_claude_session "$prompt" "manual-edit" "claude-opus-4-6"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    echo -e "${GREEN}✓ 수정 완료${NC}"
    echo ""
    echo -e "  ${BOLD}1. Re-review${NC}: claude-flow ${feature} --review"
    echo -e "  ${BOLD}2. Continue${NC}:  claude-flow ${feature} --continue"
  elif [[ $rc -eq 130 ]]; then
    echo -e "${YELLOW}⏸ 수정 중단됨 (사용자 인터럽트)${NC}"
    return 1
  else
    echo -e "${RED}✗ 수정 실패${NC}"
    return 1
  fi
}

# ── Status: show pipeline progress ──

cmd_status() {
  if [[ $# -lt 1 ]]; then
    echo -e "${RED}Usage: claude-flow status <feature>${NC}"
    return 1
  fi

  local feature="$1"
  local flow_json
  flow_json=$(find_flow_json "$feature")
  if [[ -z "$flow_json" ]]; then
    echo -e "${RED}Pipeline not found for: ${feature}${NC}"
    return 1
  fi
  show_status "$flow_json"
}

# ── Stages: show all stages and deps ──

cmd_stages() {
  # If feature is given, show stages from its flow.json
  if [[ $# -ge 1 && -n "${1:-}" ]]; then
    local feature="$1"
    local flow_json
    flow_json=$(find_flow_json "$feature")
    if [[ -n "$flow_json" ]]; then
      echo -e "${BOLD}Pipeline Stages: ${feature}${NC}"
      echo ""
      local stage
      while IFS= read -r stage; do
        [[ -z "$stage" ]] && continue
        local type phase deps
        type=$(get_stage_type "$flow_json" "$stage")
        phase=$(get_stage_phase "$flow_json" "$stage")
        deps=$(get_stage_deps "$flow_json" "$stage")
        printf "  %-30s %-8s %-10s %s\n" "$stage" "[$type]" "{$phase}" "${deps:+<- $deps}"
      done <<< "$(get_stage_order "$flow_json")"
      return 0
    fi
  fi

  # Otherwise, show stages from flow.yaml (if available)
  local flow_yaml
  flow_yaml=$(find_flow_yaml)
  if [[ -n "$flow_yaml" ]]; then
    echo -e "${BOLD}Configured Pipeline Stages${NC}"
    echo -e "${DIM}(from ${flow_yaml})${NC}"
    echo ""

    # Generate a temporary flow.json to show stages
    local tmp_output
    tmp_output=$(mktemp)
    generate_flow_json "preview" "preview" "$flow_yaml" "$tmp_output" 2>/dev/null

    if [[ -f "$tmp_output" ]]; then
      local stage
      while IFS= read -r stage; do
        [[ -z "$stage" ]] && continue
        local type phase deps
        type=$(jq -r ".stages.\"$stage\".type // \"\"" "$tmp_output")
        phase=$(jq -r ".stages.\"$stage\".phase // \"\"" "$tmp_output")
        deps=$(jq -r ".stages.\"$stage\".deps // [] | join(\",\")" "$tmp_output")
        printf "  %-30s %-8s %-10s %s\n" "$stage" "[$type]" "{$phase}" "${deps:+<- $deps}"
      done <<< "$(jq -r '.stage_order[]' "$tmp_output")"
      rm -f "$tmp_output"
    else
      echo -e "${YELLOW}Could not generate stage list from flow.yaml${NC}"
    fi
  else
    echo -e "${YELLOW}No flow.yaml found. Run 'claude-flow setup' first.${NC}"
  fi
}

# ═══════════════════════════════════════════════════════════════
# CLI Dispatch
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in
  setup)
    shift
    cmd_setup "$@"
    ;;
  init)
    shift
    cmd_init "$@"
    ;;
  run)
    shift
    cmd_run "$@"
    ;;
  status)
    shift
    cmd_status "$@"
    ;;
  stages)
    shift
    cmd_stages "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  "")
    usage
    ;;
  *)
    # Check for "feature --continue", "feature --review", "feature --edit" patterns
    if [[ "${2:-}" == "--continue" ]]; then
      cmd_continue "$1"
    elif [[ "${2:-}" == "--force-continue" ]]; then
      cmd_continue "$1" "true"
    elif [[ "${2:-}" == "--review" ]]; then
      cmd_review "$1"
    elif [[ "${2:-}" == "--edit" ]]; then
      cmd_edit "$1" "${@:3}"
    else
      echo "Unknown command: $1"
      echo ""
      usage
      exit 1
    fi
    ;;
esac
