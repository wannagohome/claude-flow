#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/engine.sh — Stage Dispatcher + Orchestration Loop
# ═══════════════════════════════════════════════════════════════
# Contains all stage runners (write, audit, gate, manual, test,
# e2e, test-fix, ui-verify, code-review), the main dispatcher,
# orchestration loop, and status display functions.
#
# All stage metadata is read from flow.json dynamically.
# No hardcoded stage names or STAGE_ORDER array.
# ═══════════════════════════════════════════════════════════════

# ── Write Stage Runner ──

run_write_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (write) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  local prompt
  prompt=$(assemble_prompt "$flow_json" "$stage") || return 1

  local model
  model=$(get_model "$flow_json" "$stage")

  run_claude_session "$prompt" "$stage" "$model"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    set_status "$flow_json" "$stage" "complete"
    echo -e "${GREEN}✓ ${stage} complete${NC}"
    return 0
  elif [[ $rc -eq 130 ]]; then
    set_status "$flow_json" "$stage" "interrupted"
    echo -e "${YELLOW}⏸ ${stage} interrupted${NC}"
    return 1
  else
    set_status "$flow_json" "$stage" "failed"
    echo -e "${RED}✗ ${stage} failed${NC}"
    return 1
  fi
}

# ── Audit Stage Runner (read-only, single pass) ──

run_audit_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (audit — read-only) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  local prompt
  prompt=$(assemble_prompt "$flow_json" "$stage") || return 1

  local model
  model=$(get_model "$flow_json" "$stage")

  run_claude_session "$prompt" "$stage" "$model"
  local rc=$?

  if [[ $rc -eq 130 ]]; then
    set_status "$flow_json" "$stage" "interrupted"
    echo -e "${YELLOW}⏸ ${stage} interrupted${NC}"
    return 1
  elif [[ $rc -eq 0 ]]; then
    # Audit always completes — findings are for human review
    set_status "$flow_json" "$stage" "complete"

    # Show findings summary if result file exists
    local result_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}.json"
    if [[ -f "$result_file" ]]; then
      local findings
      findings=$(read_json "$result_file" ".findings // 0")
      local report
      report=$(read_json "$result_file" ".report_file // \"\"")
      echo -e "${GREEN}✓ ${stage} complete — ${findings} finding(s)${NC}"
      if [[ -n "$report" && "$report" != "" ]]; then
        echo -e "${DIM}  Review report: ${report}${NC}"
      fi
    else
      echo -e "${GREEN}✓ ${stage} complete${NC}"
    fi
    return 0
  else
    set_status "$flow_json" "$stage" "failed"
    echo -e "${RED}✗ ${stage} failed${NC}"
    return 1
  fi
}

# ── Gate Stage Runner (deterministic shell script) ──

run_gate_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (deterministic gate) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  # Read gate script path from flow.json
  local gate_script
  gate_script=$(read_json "$flow_json" ".stages.\"$stage\".script_path // \"\"")

  if [[ -z "$gate_script" || ! -f "$gate_script" ]]; then
    echo -e "${YELLOW}⚠ Gate script not found for ${stage}. Skipping.${NC}"
    set_status "$flow_json" "$stage" "skipped"
    return 0
  fi

  local base_dir
  base_dir="${PROJECT_ROOT}/$(read_json "$flow_json" ".base_dir")"

  if bash "$gate_script" "$flow_json" "$base_dir" "$PROJECT_ROOT"; then
    set_status "$flow_json" "$stage" "complete"
    echo -e "${GREEN}✓ ${stage} passed${NC}"
    return 0
  else
    set_status "$flow_json" "$stage" "failed"
    echo -e "${RED}✗ ${stage} failed${NC}"
    return 1
  fi
}

# ── Manual Gate Handler ──

handle_manual_gate() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")
  local feature
  feature=$(read_json "$flow_json" ".feature")

  echo ""
  echo -e "${YELLOW}${BOLD}⏸  [${phase}] Manual review: ${stage}${NC}"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")

  # Look for review report in the phase directory
  local report=""
  # Try common report locations based on phase
  for candidate in \
    "${PROJECT_ROOT}/${base_dir}/spec/review-report.md" \
    "${PROJECT_ROOT}/${base_dir}/test-plan/review-report.md" \
    "${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-report.md"; do
    if [[ -f "$candidate" ]]; then
      report="$candidate"
      break
    fi
  done

  if [[ -n "$report" ]]; then
    echo -e "${DIM}   Review report: ${report}${NC}"
  fi
  echo ""
  echo -e "   ${BOLD}1. Edit${NC}:     claude-flow ${feature} --edit \"수정 요청\""
  echo -e "      (AI가 수정 요청을 반영)"
  echo -e "   ${BOLD}2. Continue${NC}: claude-flow ${feature} --continue"
  echo -e "      (만족하면 다음 Phase로 진행)"
  echo ""

  set_status "$flow_json" "$stage" "waiting"
}

# ═══════════════════════════════════════════════════════════════
# Special Stage Handlers
# ═══════════════════════════════════════════════════════════════

# ── Code Review Stage (pre-gates + review loop) ──

run_code_review_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (pre-gate + review) ═══${NC}"

  cd "$PROJECT_ROOT"
  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")

  # Read pre_gates from flow.json overrides (default: compile, lint)
  local pre_gates
  pre_gates=$(read_json "$flow_json" '.config.code_review.pre_gates // [] | .[]' 2>/dev/null)
  if [[ -z "$pre_gates" ]]; then
    # Fallback: no pre-gates configured, skip pre-gate phase
    echo -e "${DIM}  No pre-gates configured, proceeding to review${NC}"
  else
    local pregate_pass=true
    local gate_num=0
    local gate_total
    gate_total=$(echo "$pre_gates" | wc -l | tr -d ' ')

    while IFS= read -r gate_cmd; do
      [[ -z "$gate_cmd" ]] && continue
      gate_num=$((gate_num + 1))
      echo -e "${DIM}  Pre-gate ${gate_num}/${gate_total}: ${gate_cmd}${NC}"

      # Check if gate_cmd is a script path or a command
      if [[ -f "$gate_cmd" ]]; then
        if ! bash "$gate_cmd" "$flow_json" "${PROJECT_ROOT}/${base_dir}" "$PROJECT_ROOT" 2>&1; then
          pregate_pass=false
          echo -e "${YELLOW}  ${gate_cmd} failed.${NC}"
        fi
      else
        if ! eval "$gate_cmd" 2>&1; then
          pregate_pass=false
          echo -e "${YELLOW}  ${gate_cmd} failed.${NC}"
        fi
      fi
    done <<< "$pre_gates"

    if [[ "$pregate_pass" == "true" ]]; then
      echo -e "${GREEN}  Pre-gates passed.${NC}"
    fi
  fi

  # Use standard review loop
  run_review_stage "$flow_json" "$stage"
}

# ── Test Stage Runner ──

run_test_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (test execution) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  cd "$PROJECT_ROOT"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  local log_file="${PROJECT_ROOT}/${base_dir}/.pipeline/unit-test.log"

  # Read test command from flow.json config
  local test_command
  test_command=$(read_json "$flow_json" '.config.test.unit.command // "npm test"')

  if eval "$test_command" 2>&1 | tee "$log_file"; then
    set_status "$flow_json" "$stage" "complete"
    echo -e "${GREEN}✓ All tests passed${NC}"
    return 0
  else
    set_status "$flow_json" "$stage" "complete"
    echo -e "${YELLOW}  Tests failed. Log: ${log_file}${NC}"
    echo -e "${YELLOW}  test-fix will analyze and repair.${NC}"
    return 0
  fi
}

# ── E2E Test Stage Runner ──

run_e2e_stage() {
  local flow_json="$1" stage="$2"
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (E2E test execution) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  cd "$PROJECT_ROOT"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  local feature_slug
  feature_slug=$(read_json "$flow_json" ".feature_slug")

  # Read E2E config from flow.json
  local e2e_command
  e2e_command=$(read_json "$flow_json" '.config.test.e2e.command // ""')

  if [[ -z "$e2e_command" ]]; then
    echo -e "${YELLOW}⚠ No E2E command configured. Skipping.${NC}"
    set_status "$flow_json" "$stage" "skipped"
    return 0
  fi

  # Optional setup command
  local setup_command
  setup_command=$(read_json "$flow_json" '.config.test.e2e.setup_command // ""')
  if [[ -n "$setup_command" && "$setup_command" != "null" ]]; then
    echo -e "${DIM}  Running E2E setup: ${setup_command}${NC}"
    eval "$setup_command" 2>&1 || true
  fi

  echo -e "  Feature: ${feature_slug}"

  # WebView: start web dev server if configured
  local web_workspace web_server_pid=0
  web_workspace=$(read_json "$flow_json" '.config.test.e2e.web_workspace // ""')
  if [[ -z "$web_workspace" ]]; then
    web_workspace=$(read_json "$flow_json" '.config.web_workspace // ""')
  fi

  if [[ -n "$web_workspace" && -d "$web_workspace" ]]; then
    local web_dev_cmd
    web_dev_cmd=$(read_json "$flow_json" '.config.test.e2e.setup_command // "npm run dev -- --host"')
    local web_port
    web_port=$(read_json "$flow_json" '.config.test.e2e.setup_port // 5173')
    echo -e "  Starting web dev server: ${web_workspace}"
    (cd "$web_workspace" && eval "$web_dev_cmd" 2>/dev/null) &
    web_server_pid=$!
    # Wait for port (max 30s)
    local wait_count=0
    while ! lsof -i :"$web_port" -sTCP:LISTEN >/dev/null 2>&1; do
      sleep 1
      wait_count=$((wait_count + 1))
      if [[ $wait_count -ge 30 ]]; then
        echo -e "${YELLOW}  ⚠ Web dev server failed to start within 30s${NC}"
        kill "$web_server_pid" 2>/dev/null || true
        web_server_pid=0
        break
      fi
    done
    if [[ $web_server_pid -ne 0 ]]; then
      echo -e "${GREEN}  ✓ Web dev server ready (port ${web_port})${NC}"
    fi
  fi

  local log_file="${PROJECT_ROOT}/${base_dir}/.pipeline/e2e-test.log"

  local e2e_exit=0
  if ! eval "$e2e_command" 2>&1 | tee "$log_file"; then
    e2e_exit=1
  fi

  # Cleanup web server
  if [[ $web_server_pid -ne 0 ]]; then
    kill "$web_server_pid" 2>/dev/null || true
    wait "$web_server_pid" 2>/dev/null || true
    echo -e "  Web dev server stopped"
  fi

  if [[ $e2e_exit -eq 0 ]]; then
    set_status "$flow_json" "$stage" "complete"
    echo -e "${GREEN}✓ E2E tests passed${NC}"
    return 0
  else
    set_status "$flow_json" "$stage" "complete"
    echo -e "${YELLOW}  E2E tests failed. Log: ${log_file}${NC}"
    echo -e "${YELLOW}  test-fix will analyze and repair.${NC}"
    return 0
  fi
}

# ── Test Fix Stage (fix + retest loop, unlimited rounds) ──

run_test_fix_stage() {
  local flow_json="$1" stage="$2"
  local max_rounds=999
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (fix + retest loop, unlimited) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  # Resume from last completed round
  local completed_rounds
  completed_rounds=$(read_json "$flow_json" ".stages.\"${stage}\".rounds | length")
  completed_rounds="${completed_rounds:-0}"
  local start_round=$((completed_rounds + 1))

  if [[ "$start_round" -gt 1 ]]; then
    echo -e "${DIM}  Resuming from round ${start_round} (${completed_rounds} rounds completed)${NC}"
  fi

  # Find test stage names dynamically from flow.json
  local test_stages
  test_stages=$(read_json "$flow_json" '[.stages | to_entries[] | select(.value.handler == "test-run" or .value.handler == "test-e2e" or .value.type == "test") | .key] | .[]' 2>/dev/null)

  for round in $(seq "$start_round" "$max_rounds"); do
    echo -e "${YELLOW}  -- Round ${round}/${max_rounds} --${NC}"

    local prompt
    prompt=$(assemble_prompt "$flow_json" "$stage" "$round") || return 1

    local model
    model=$(get_model "$flow_json" "$stage" "$round")

    run_claude_session "$prompt" "${stage}-r${round}" "$model"
    local rc=$?
    if [[ $rc -eq 130 ]]; then
      set_status "$flow_json" "$stage" "interrupted"
      echo -e "${YELLOW}⏸ ${stage} interrupted in round ${round}${NC}"
      return 1
    elif [[ $rc -eq 75 ]]; then
      set_status "$flow_json" "$stage" "rate_limited"
      echo -e "${YELLOW}⏸ ${stage} rate limited in round ${round}${NC}"
      echo -e "${YELLOW}  Resume later: claude-flow <feature> --continue${NC}"
      return 1
    elif [[ $rc -ne 0 ]]; then
      set_status "$flow_json" "$stage" "failed"
      echo -e "${RED}✗ ${stage} failed in round ${round} (exit code: ${rc})${NC}"
      return 1
    fi

    # Read findings and fixed count
    local result_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-round-${round}.json"
    local findings=0
    local fixed=0
    if [[ -f "$result_file" ]]; then
      findings=$(read_json "$result_file" ".findings // 0")
      fixed=$(read_json "$result_file" ".fixed // 0")
    else
      echo -e "${YELLOW}  ⚠ No result file found, assuming findings remain${NC}"
      findings=1
    fi

    # Record round
    update_json "$flow_json" \
      ".stages.\"${stage}\".rounds += [{\"round\": ${round}, \"findings\": ${findings}, \"fixed\": ${fixed}}]"

    echo -e "  Findings: ${findings}, Fixed: ${fixed}"

    # If any fixes were made, re-run test stages to verify
    if [[ "$fixed" -gt 0 ]]; then
      echo -e "${BLUE}  ↻ Resetting test stages to verify fixes${NC}"
      # Reset dependent test stages
      while IFS= read -r ts; do
        [[ -z "$ts" ]] && continue
        set_status "$flow_json" "$ts" "pending"
      done <<< "$test_stages"
      set_status "$flow_json" "$stage" "pending"
      return 0
    fi

    if [[ "$findings" -eq 0 ]]; then
      set_status "$flow_json" "$stage" "complete"
      echo -e "${GREEN}✓ ${stage} passed after ${round} round(s)${NC}"
      return 0
    fi

    # Findings > 0 but nothing fixed: reset test stages anyway
    echo -e "${BLUE}  ↻ Resetting test stages for re-verification${NC}"
    while IFS= read -r ts; do
      [[ -z "$ts" ]] && continue
      set_status "$flow_json" "$ts" "pending"
    done <<< "$test_stages"
    set_status "$flow_json" "$stage" "pending"
    return 0
  done
}

# ── UI Verify Stage (verify + fix loop, unlimited rounds) ──

run_ui_verify_stage() {
  local flow_json="$1" stage="$2"
  local max_rounds=999
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (verify + fix loop, unlimited) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  # Resume from last completed round
  local completed_rounds
  completed_rounds=$(read_json "$flow_json" ".stages.\"${stage}\".rounds | length")
  completed_rounds="${completed_rounds:-0}"
  local start_round=$((completed_rounds + 1))

  if [[ "$start_round" -gt 1 ]]; then
    echo -e "${DIM}  Resuming from round ${start_round} (${completed_rounds} rounds completed)${NC}"
  fi

  # Find test stage names dynamically from flow.json
  local test_stages
  test_stages=$(read_json "$flow_json" '[.stages | to_entries[] | select(.value.handler == "test-run" or .value.handler == "test-e2e" or .value.type == "test") | .key] | .[]' 2>/dev/null)

  for round in $(seq "$start_round" "$max_rounds"); do
    echo -e "${YELLOW}  -- Round ${round}/${max_rounds} --${NC}"

    local prompt
    prompt=$(assemble_prompt "$flow_json" "$stage" "$round") || return 1

    local model
    model=$(get_model "$flow_json" "$stage" "$round")

    run_claude_session "$prompt" "${stage}-r${round}" "$model"
    local rc=$?
    if [[ $rc -eq 130 ]]; then
      set_status "$flow_json" "$stage" "interrupted"
      echo -e "${YELLOW}⏸ ${stage} interrupted in round ${round}${NC}"
      return 1
    elif [[ $rc -eq 75 ]]; then
      set_status "$flow_json" "$stage" "rate_limited"
      echo -e "${YELLOW}⏸ ${stage} rate limited in round ${round}${NC}"
      echo -e "${YELLOW}  Resume later: claude-flow <feature> --continue${NC}"
      return 1
    elif [[ $rc -ne 0 ]]; then
      set_status "$flow_json" "$stage" "failed"
      echo -e "${RED}✗ ${stage} failed in round ${round} (exit code: ${rc})${NC}"
      return 1
    fi

    # Read findings and fixed count
    local result_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-round-${round}.json"
    local findings=0
    local fixed=0
    if [[ -f "$result_file" ]]; then
      findings=$(read_json "$result_file" ".findings // 0")
      fixed=$(read_json "$result_file" ".fixed // 0")
    else
      echo -e "${YELLOW}  ⚠ No result file found, assuming findings remain${NC}"
      findings=1
    fi

    # Record round
    update_json "$flow_json" \
      ".stages.\"${stage}\".rounds += [{\"round\": ${round}, \"findings\": ${findings}, \"fixed\": ${fixed}}]"

    echo -e "  Findings: ${findings}, Fixed: ${fixed}"

    # If any fixes were made, re-run tests to verify, then come back
    if [[ "$fixed" -gt 0 ]]; then
      echo -e "${BLUE}  ↻ Resetting test stages to verify UI fixes${NC}"
      while IFS= read -r ts; do
        [[ -z "$ts" ]] && continue
        set_status "$flow_json" "$ts" "pending"
      done <<< "$test_stages"
      set_status "$flow_json" "$stage" "pending"
      return 0
    fi

    if [[ "$findings" -eq 0 ]]; then
      set_status "$flow_json" "$stage" "complete"
      echo -e "${GREEN}✓ ${stage} passed after ${round} round(s)${NC}"
      return 0
    fi

    # Findings > 0 but nothing fixed: reset test stages for re-verification
    echo -e "${BLUE}  ↻ Resetting test stages for re-verification${NC}"
    while IFS= read -r ts; do
      [[ -z "$ts" ]] && continue
      set_status "$flow_json" "$ts" "pending"
    done <<< "$test_stages"
    set_status "$flow_json" "$stage" "pending"
    return 0
  done
}

# ═══════════════════════════════════════════════════════════════
# Stage Dispatcher
# ═══════════════════════════════════════════════════════════════

run_single_stage() {
  local flow_json="$1" stage="$2"
  local stage_result=0

  local type
  type=$(get_stage_type "$flow_json" "$stage")

  # Check for special handler in flow.json stage metadata
  local handler
  handler=$(read_json "$flow_json" ".stages.\"$stage\".handler // \"\"")

  case "${handler:-$type}" in
    code-review)  run_code_review_stage "$flow_json" "$stage"; stage_result=$? ;;
    test-run)     run_test_stage "$flow_json" "$stage"; stage_result=$? ;;
    test-e2e)     run_e2e_stage "$flow_json" "$stage"; stage_result=$? ;;
    test-fix)     run_test_fix_stage "$flow_json" "$stage"; stage_result=$? ;;
    ui-verify)    run_ui_verify_stage "$flow_json" "$stage"; stage_result=$? ;;
    write)        run_write_stage "$flow_json" "$stage"; stage_result=$? ;;
    review)       run_review_stage "$flow_json" "$stage"; stage_result=$? ;;
    audit)        run_audit_stage "$flow_json" "$stage"; stage_result=$? ;;
    gate)         run_gate_stage "$flow_json" "$stage"; stage_result=$? ;;
    manual)       handle_manual_gate "$flow_json" "$stage"; return 0 ;;
    *)
      echo -e "${RED}Unknown stage type/handler: ${handler:-$type} for stage: ${stage}${NC}"
      return 1
      ;;
  esac

  return $stage_result
}

# ═══════════════════════════════════════════════════════════════
# Main Orchestration Loop
# ═══════════════════════════════════════════════════════════════

run_pipeline() {
  local flow_json="$1"
  local feature
  feature=$(read_json "$flow_json" ".feature")

  # macOS sleep prevention — auto-released on pipeline exit
  caffeinate -dims &
  local caffeinate_pid=$!
  trap "kill $caffeinate_pid 2>/dev/null" EXIT

  echo -e "${BOLD}═══ Pipeline: ${feature} ═══${NC}"
  echo -e "${DIM}  ☕ caffeinate active (pid: ${caffeinate_pid}) — 잠자기 방지 중${NC}"
  echo ""

  while true; do
    local ready_stages
    ready_stages=$(get_ready_stages "$flow_json")

    if [[ -z "$ready_stages" ]]; then
      if is_all_complete "$flow_json"; then
        echo ""
        echo -e "${GREEN}${BOLD}═══ Pipeline Complete ═══${NC}"
        show_summary "$flow_json"
        return 0
      fi

      # Check for waiting manual gates
      local stage
      while IFS= read -r stage; do
        [[ -z "$stage" ]] && continue
        local status
        status=$(get_status "$flow_json" "$stage")
        if [[ "$status" == "waiting" ]]; then
          # Already displaying manual gate prompt
          return 0
        fi
      done <<< "$(get_stage_order "$flow_json")"

      # Check for failures or orphaned running stages
      while IFS= read -r stage; do
        [[ -z "$stage" ]] && continue
        local status
        status=$(get_status "$flow_json" "$stage")
        if [[ "$status" == "failed" || "$status" == "running" || "$status" == "interrupted" || "$status" == "rate_limited" ]]; then
          echo -e "${YELLOW}Pipeline stopped: ${stage} ${status}.${NC}"
          echo -e "Resume: claude-flow ${feature} --continue"
          echo -e "Or retry: claude-flow run ${feature} --stage ${stage}"
          return 1
        fi
      done <<< "$(get_stage_order "$flow_json")"

      echo -e "${RED}Pipeline stuck. Check status: claude-flow status ${feature}${NC}"
      return 1
    fi

    # Parse ready stages into array
    IFS=' ' read -ra stages_arr <<< "$ready_stages"

    # Check if any are manual gates
    local has_manual=false
    for s in "${stages_arr[@]}"; do
      if [[ "$(get_stage_type "$flow_json" "$s")" == "manual" ]]; then
        handle_manual_gate "$flow_json" "$s"
        has_manual=true
      fi
    done
    [[ "$has_manual" == "true" ]] && return 0

    if [[ ${#stages_arr[@]} -gt 1 ]]; then
      # Multiple stages ready -> run in parallel
      echo -e "${BLUE}▶ Running ${#stages_arr[@]} stages in parallel: ${stages_arr[*]}${NC}"
      local pids=()
      for s in "${stages_arr[@]}"; do
        run_single_stage "$flow_json" "$s" &
        pids+=($!)
      done

      local any_failed=false
      for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
          any_failed=true
        fi
      done

      if [[ "$any_failed" == "true" ]]; then
        echo -e "${RED}One or more parallel stages failed.${NC}"
        return 1
      fi
    else
      # Single stage
      run_single_stage "$flow_json" "${stages_arr[0]}" || return 1
    fi
  done
}

# ═══════════════════════════════════════════════════════════════
# Status Display
# ═══════════════════════════════════════════════════════════════

show_status() {
  local flow_json="$1"
  local feature
  feature=$(read_json "$flow_json" ".feature")

  echo -e "${BOLD}Pipeline: ${feature}${NC}"
  echo -e "${DIM}$(read_json "$flow_json" ".base_dir")${NC}"
  echo ""

  local current_phase=""
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status phase type
    status=$(get_status "$flow_json" "$stage")
    phase=$(get_stage_phase "$flow_json" "$stage")
    type=$(get_stage_type "$flow_json" "$stage")

    # Phase header
    if [[ "$phase" != "$current_phase" ]]; then
      current_phase="$phase"
      echo -e "${DIM}── ${phase} ──${NC}"
    fi

    # Status icon
    local icon
    case "$status" in
      complete)      icon="${GREEN}✓${NC}" ;;
      running)       icon="${BLUE}▶${NC}" ;;
      waiting)       icon="${YELLOW}⏸${NC}" ;;
      interrupted)   icon="${YELLOW}⊘${NC}" ;;
      failed)        icon="${RED}✗${NC}" ;;
      skipped)       icon="${DIM}⊘${NC}" ;;
      max_exceeded)  icon="${YELLOW}⚠${NC}" ;;
      pending)       icon="${DIM}○${NC}" ;;
      rate_limited)  icon="${YELLOW}⏸${NC}" ;;
      *)             icon="${DIM}?${NC}" ;;
    esac

    # Round info for review stages
    local extra=""
    if [[ "$type" == "review" ]]; then
      local rounds
      rounds=$(read_json "$flow_json" ".stages.\"${stage}\".rounds | length")
      if [[ "$rounds" -gt 0 ]]; then
        extra=" ${DIM}(${rounds} rounds)${NC}"
      fi
    fi

    printf "  %b %-30s %b%b\n" "$icon" "$stage" "$status" "$extra"
  done <<< "$(get_stage_order "$flow_json")"
  echo ""
}

show_summary() {
  local flow_json="$1"
  echo ""
  echo -e "${DIM}─────────────────────────────────${NC}"

  local total=0 complete=0 skipped=0 max_exc=0
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")
    ((total++))
    case "$status" in
      complete)     ((complete++)) ;;
      skipped)      ((skipped++)) ;;
      max_exceeded) ((max_exc++)) ;;
    esac
  done <<< "$(get_stage_order "$flow_json")"

  echo -e "  Total: ${total}  Complete: ${GREEN}${complete}${NC}  Skipped: ${DIM}${skipped}${NC}  Escalated: ${YELLOW}${max_exc}${NC}"
}
