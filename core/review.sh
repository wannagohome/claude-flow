#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/review.sh — Review Loop + Claude Session Execution
# ═══════════════════════════════════════════════════════════════
# Contains the claude -p session runner and the multi-round
# adversarial review loop. Exit codes:
#   0   = success
#   1   = error
#   75  = rate limited
#   130 = interrupted (SIGINT)
# ═══════════════════════════════════════════════════════════════

# ── Claude Session Runner ──

run_claude_session() {
  local prompt="$1" stage="$2" model="${3:-claude-opus-4-6}"
  local prompt_file stderr_file
  prompt_file=$(mktemp /tmp/flow-prompt-XXXXXX)
  stderr_file=$(mktemp /tmp/flow-stderr-XXXXXX)
  echo "$prompt" > "$prompt_file"

  echo -e "${DIM}  claude -p session starting (model: ${model})...${NC}"

  # Trap SIGINT to detect Ctrl+C during claude session
  local interrupted=false
  trap 'interrupted=true' INT

  # Temporarily disable pipefail to capture claude's exit code via PIPESTATUS
  # jq might fail on unexpected input; || true ensures pipe doesn't break
  set +o pipefail
  claude -p "$(cat "$prompt_file")" \
    --model "$model" \
    --dangerously-skip-permissions \
    --verbose \
    --output-format stream-json 2> >(tee "$stderr_file" >&2) | \
    jq --unbuffered -r '
      if .type == "assistant" then
        [.message.content[]? | select(.type == "tool_use") |
          if .name == "Agent" then
            "  \u001b[36m⚙ Agent [\(.input.name // .input.subagent_type // "?")]: \(.input.description // "")\u001b[0m"
          else
            "  \u001b[2m⚙ \(.name): \(.input.file_path // .input.command // .input.pattern // "")\u001b[0m"
          end
        ] | .[]
      elif .type == "result" then
        .result // empty
      else
        empty
      end
    ' 2>/dev/null || true
  local exit_code=${PIPESTATUS[0]}
  set -o pipefail

  # Restore default SIGINT handler
  trap - INT

  rm -f "$prompt_file"

  if [[ "$interrupted" == "true" ]]; then
    echo -e "${YELLOW}  claude session interrupted by user (SIGINT)${NC}"
    rm -f "$stderr_file"
    return 130
  fi

  if [[ $exit_code -ne 0 ]]; then
    # Detect rate limit from stderr
    if grep -qi "rate.limit\|too many requests\|429\|quota.*exceeded\|over capacity" "$stderr_file" 2>/dev/null; then
      echo -e "${YELLOW}  claude -p rate limited (exit code: ${exit_code})${NC}"
      rm -f "$stderr_file"
      return 75
    fi
    echo -e "${RED}  claude -p exited with code ${exit_code}${NC}"
  fi
  rm -f "$stderr_file"
  return $exit_code
}

# ═══════════════════════════════════════════════════════════════
# Multi-Round Review Loop
# ═══════════════════════════════════════════════════════════════

run_review_stage() {
  local flow_json="$1" stage="$2"
  local max_rounds
  max_rounds=$(read_json "$flow_json" '.config.review.max_rounds // 3')
  local phase
  phase=$(get_stage_phase "$flow_json" "$stage")

  echo -e "${CYAN}═══ [${phase}] ${stage} (review, max ${max_rounds}) ═══${NC}"
  set_status "$flow_json" "$stage" "running"

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")
  mkdir -p "${PROJECT_ROOT}/${base_dir}/.pipeline"

  # Resume from last completed round (for interrupted sessions)
  local completed_rounds
  completed_rounds=$(read_json "$flow_json" ".stages.\"${stage}\".rounds | length")
  completed_rounds="${completed_rounds:-0}"
  local start_round=$((completed_rounds + 1))

  if [[ "$start_round" -gt 1 ]]; then
    echo -e "${DIM}  Resuming from round ${start_round} (${completed_rounds} rounds completed)${NC}"
  fi

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
    elif [[ $rc -ne 0 ]]; then
      set_status "$flow_json" "$stage" "failed"
      echo -e "${RED}✗ ${stage} failed in round ${round}${NC}"
      return 1
    fi

    # Read findings from the result file
    local result_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-round-${round}.json"
    local findings=0
    if [[ -f "$result_file" ]]; then
      findings=$(read_json "$result_file" ".findings // 0")
    else
      # If no result file, assume there were findings (conservative)
      echo -e "${YELLOW}  ⚠ No result file found, assuming findings remain${NC}"
      findings=1
    fi

    # Record round in flow.json
    update_json "$flow_json" \
      ".stages.\"${stage}\".rounds += [{\"round\": ${round}, \"findings\": ${findings}}]"

    echo -e "  Findings: ${findings}"

    if [[ "$findings" -eq 0 ]]; then
      set_status "$flow_json" "$stage" "complete"
      echo -e "${GREEN}✓ ${stage} passed after ${round} round(s)${NC}"
      return 0
    fi
  done

  # Max rounds exceeded — pause for user decision
  set_status "$flow_json" "$stage" "max_exceeded"
  local feature
  feature=$(read_json "$flow_json" ".feature")
  local last_result="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-round-${max_rounds}.json"
  local remaining_count=0
  if [[ -f "$last_result" ]]; then
    remaining_count=$(read_json "$last_result" ".findings // 0")
  fi

  echo ""
  echo -e "${YELLOW}${BOLD}⚠ ${stage}: max rounds reached (${max_rounds}), ${remaining_count} findings remain.${NC}"
  echo -e "${DIM}   Last round result: ${last_result}${NC}"
  echo ""
  echo -e "   Options:"
  echo -e "   ${BOLD}1. Edit${NC}:     claude-flow ${feature} --edit \"수정 요청\""
  echo -e "      (AI가 수정 요청을 반영)"
  echo -e "   ${BOLD}2. Retry${NC}:    claude-flow run ${feature} --stage ${stage}"
  echo -e "      (이 리뷰 스테이지 재실행)"
  echo -e "   ${BOLD}3. Continue${NC}: claude-flow ${feature} --continue"
  echo -e "      (남은 findings 무시하고 다음 단계로)"
  echo ""
  return 0
}
