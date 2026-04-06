#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/prompt.sh — 6-Layer Prompt Assembly
# ═══════════════════════════════════════════════════════════════
# Assembles prompts from 6 layers for KV-cache optimization:
#
# Layer 1: Protocol (session-context.md + result-schema.md)
#          → all stages, cacheable prefix
# Layer 2: Conventions (project's conventions.md)
#          → all stages, cacheable prefix
# Layer 3: Type Header (write-protocol.md or review-protocol.md)
#          + Session Info
# Layer 4: Stage Prompt (project override -> module default)
# Layer 5: Provider Fragments (active providers, match rules)
# Layer 6: Runtime Context (prev_round_result, gate_context)
#
# Variable substitution:
#   {FEATURE}, {BASE_DIR}, {FLOW_PATH}, {PROJECT_ROOT},
#   {RESULT_FILE}, {ROUND}, {MAX_ROUNDS},
#   {PREV_ROUND_RESULT}, {GATE_CONTEXT},
#   {PREV_FINDINGS_CONTEXT}, plus provider variables
# ═══════════════════════════════════════════════════════════════

assemble_prompt() {
  local flow_json="$1" stage="$2"
  local round="${3:-}"

  # Load basic variables
  local base_dir feature
  base_dir=$(read_json "$flow_json" ".base_dir")
  feature=$(read_json "$flow_json" ".feature")

  local type phase
  type=$(get_stage_type "$flow_json" "$stage")
  phase=$(get_stage_phase "$flow_json" "$stage")

  local max_rounds
  max_rounds=$(read_json "$flow_json" '.config.review.max_rounds // 3')

  # ── Layer 1: Protocol ──
  local layer1=""
  if [[ -f "$FLOW_HOME/protocols/session-context.md" ]]; then
    layer1=$(cat "$FLOW_HOME/protocols/session-context.md")
  fi
  if [[ -f "$FLOW_HOME/protocols/result-schema.md" ]]; then
    layer1="${layer1}

$(cat "$FLOW_HOME/protocols/result-schema.md")"
  fi

  # ── Layer 2: Conventions ──
  local layer2=""
  local conventions_path
  conventions_path=$(read_json "$flow_json" '.config.conventions_path // ""')
  if [[ -n "$conventions_path" && -f "$conventions_path" ]]; then
    layer2=$(cat "$conventions_path")
  fi

  # ── Layer 3: Type Header + Session Info ──
  local layer3=""
  if [[ "$type" == "review" || "$type" == "audit" ]]; then
    [[ -f "$FLOW_HOME/protocols/review-protocol.md" ]] && layer3=$(cat "$FLOW_HOME/protocols/review-protocol.md")
  else
    [[ -f "$FLOW_HOME/protocols/write-protocol.md" ]] && layer3=$(cat "$FLOW_HOME/protocols/write-protocol.md")
  fi

  # ── Layer 4: Stage Prompt (project override -> module default) ──
  local layer4=""
  local prompt_path
  prompt_path=$(resolve_stage_prompt "$flow_json" "$stage")
  if [[ -n "$prompt_path" && -f "$prompt_path" ]]; then
    layer4=$(cat "$prompt_path")
  else
    echo -e "${RED}Prompt not found for stage: ${stage}${NC}" >&2
    return 1
  fi

  # ── Layer 5: Provider Fragments ──
  local layer5=""
  layer5=$(collect_provider_fragments "$flow_json" "$stage" "$type" "$phase")

  # ── Assemble ──
  local prompt="${layer1}

---

## Project Conventions

${layer2}

---

${layer3}

---

${layer4}"

  # Insert provider fragments after stage prompt
  if [[ -n "$layer5" ]]; then
    prompt="${prompt}

${layer5}"
  fi

  # ── Layer 6: Runtime Context ──
  local result_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}"
  [[ -n "$round" ]] && result_file="${result_file}-round-${round}"
  result_file="${result_file}.json"

  local prev_round_result=""
  if [[ -n "$round" ]] && [[ "$round" -gt 1 ]]; then
    local prev_round=$((round - 1))
    local prev_file="${PROJECT_ROOT}/${base_dir}/.pipeline/${stage}-round-${prev_round}.json"
    if [[ -f "$prev_file" ]]; then
      prev_round_result="$prev_file"
    fi
  fi

  # Gate context for code-review and similar stages
  local gate_context=""
  gate_context=$(collect_gate_context "$flow_json" "$stage")

  # Inline previous round findings for review rounds 2+
  local prev_findings_context=""
  if [[ -n "$prev_round_result" && -f "$prev_round_result" ]]; then
    prev_findings_context="

## [PRE-INJECTED] Previous Round (Round $((round - 1))) Findings
\`\`\`json
$(jq -c '.' "$prev_round_result")
\`\`\`
위 findings가 실제로 수정되었는지 먼저 확인하세요."
  fi

  # Variable substitution
  prompt="${prompt//\{FEATURE\}/${feature}}"
  prompt="${prompt//\{BASE_DIR\}/${PROJECT_ROOT}/${base_dir}}"
  prompt="${prompt//\{FLOW_PATH\}/${flow_json}}"
  prompt="${prompt//\{PROJECT_ROOT\}/${PROJECT_ROOT}}"
  prompt="${prompt//\{RESULT_FILE\}/${result_file}}"
  prompt="${prompt//\{ROUND\}/${round:-1}}"
  prompt="${prompt//\{MAX_ROUNDS\}/${max_rounds}}"
  prompt="${prompt//\{PREV_ROUND_RESULT\}/${prev_round_result}}"
  prompt="${prompt//\{GATE_CONTEXT\}/${gate_context}}"
  prompt="${prompt//\{PREV_FINDINGS_CONTEXT\}/${prev_findings_context}}"

  # Provider variable substitution
  inject_provider_variables "$flow_json" prompt

  # Append runtime contexts at the end (dynamic, not in cacheable prefix)
  [[ -n "$gate_context" ]] && prompt="${prompt}${gate_context}"
  [[ -n "$prev_findings_context" ]] && prompt="${prompt}${prev_findings_context}"

  echo "$prompt"
}

# ═══════════════════════════════════════════════════════════════
# Stage Prompt Resolution
# ═══════════════════════════════════════════════════════════════

resolve_stage_prompt() {
  local flow_json="$1" stage="$2"

  # 1. Project override
  local project_prompt="${PROJECT_ROOT}/.claude/flow/prompts/${stage}.md"
  [[ -f "$project_prompt" ]] && echo "$project_prompt" && return

  # 2. Module default (from flow.json)
  local module_prompt
  module_prompt=$(read_json "$flow_json" ".stages.\"$stage\".prompt_path // \"\"")
  [[ -n "$module_prompt" && -f "$module_prompt" ]] && echo "$module_prompt" && return

  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Provider Fragment Collection
# ═══════════════════════════════════════════════════════════════

collect_provider_fragments() {
  local flow_json="$1" stage="$2" type="$3" phase="$4"
  local fragments=""

  # Get list of enabled providers from flow.json
  local providers
  providers=$(read_json "$flow_json" '[.config.providers | to_entries[] | select(.value.enabled == true) | .key] | .[]')

  for provider_name in $providers; do
    local provider_dir
    provider_dir=$(resolve_provider_dir "$provider_name")
    [[ -z "$provider_dir" ]] && continue

    local provider_yaml="${provider_dir}/provider.yaml"
    [[ ! -f "$provider_yaml" ]] && continue

    # Iterate fragments in provider.yaml and check match rules
    local frag_count
    frag_count=$(yq '.fragments | length' "$provider_yaml" 2>/dev/null || echo 0)

    for i in $(seq 0 $((frag_count - 1))); do
      local match_phase match_type match_stage frag_file
      match_phase=$(yq ".fragments[$i].match.phase // \"\"" "$provider_yaml")
      match_type=$(yq ".fragments[$i].match.type // \"\"" "$provider_yaml")
      match_stage=$(yq ".fragments[$i].match.stage // \"\"" "$provider_yaml")
      frag_file=$(yq ".fragments[$i].file" "$provider_yaml")

      local matched=false

      # Exact stage name match
      if [[ -n "$match_stage" && "$match_stage" != "null" && "$match_stage" == "$stage" ]]; then
        matched=true
      # Phase + type match
      elif [[ -n "$match_phase" && "$match_phase" != "null" && \
              -n "$match_type" && "$match_type" != "null" && \
              "$match_phase" == "$phase" && "$match_type" == "$type" ]]; then
        matched=true
      # Phase-only match
      elif [[ -n "$match_phase" && "$match_phase" != "null" && \
              ( -z "$match_type" || "$match_type" == "null" ) && \
              "$match_phase" == "$phase" ]]; then
        matched=true
      fi

      if [[ "$matched" == "true" && -f "${provider_dir}/${frag_file}" ]]; then
        fragments="${fragments}

$(cat "${provider_dir}/${frag_file}")"
      fi
    done
  done

  echo "$fragments"
}

# ═══════════════════════════════════════════════════════════════
# Provider Directory Resolution
# ═══════════════════════════════════════════════════════════════

resolve_provider_dir() {
  local name="$1"

  # 1. Project local
  local local_dir="${PROJECT_ROOT}/.claude/flow/providers/${name}"
  [[ -d "$local_dir" ]] && echo "$local_dir" && return

  # 2. npm package
  local npm_dir="${PROJECT_ROOT}/node_modules/claude-flow-provider-${name}"
  [[ -d "$npm_dir" ]] && echo "$npm_dir" && return

  # 3. Built-in
  local builtin_dir="${FLOW_HOME}/providers/${name}"
  [[ -d "$builtin_dir" ]] && echo "$builtin_dir" && return

  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Provider Variable Injection
# ═══════════════════════════════════════════════════════════════

inject_provider_variables() {
  local flow_json="$1"
  local -n prompt_ref="$2"

  local providers
  providers=$(read_json "$flow_json" '[.config.providers | to_entries[] | select(.value.enabled == true) | .key] | .[]')

  for provider_name in $providers; do
    local provider_dir
    provider_dir=$(resolve_provider_dir "$provider_name")
    [[ -z "$provider_dir" ]] && continue

    local provider_yaml="${provider_dir}/provider.yaml"
    [[ ! -f "$provider_yaml" ]] && continue

    local var_count
    var_count=$(yq '.variables | length' "$provider_yaml" 2>/dev/null || echo 0)

    for i in $(seq 0 $((var_count - 1))); do
      local var_name
      var_name=$(yq ".variables[$i].name" "$provider_yaml")

      # Look up value from flow.json config
      local var_key
      var_key=$(echo "$var_name" | tr '[:upper:]' '[:lower:]')
      local var_value
      var_value=$(read_json "$flow_json" ".config.providers.${provider_name}.config.${var_key} // \"\"")

      prompt_ref="${prompt_ref//\{${var_name}\}/${var_value}}"
    done
  done
}

# ═══════════════════════════════════════════════════════════════
# Gate Context Collection
# ═══════════════════════════════════════════════════════════════

collect_gate_context() {
  local flow_json="$1" stage="$2"
  local gate_context=""

  local base_dir
  base_dir=$(read_json "$flow_json" ".base_dir")

  # Check for pre-gate results that should be injected
  # Code-review stages typically need checklist and integration issue data
  local handler
  handler=$(read_json "$flow_json" ".stages.\"$stage\".handler // \"\"")

  if [[ "$handler" == "code-review" || "$stage" == *"code-review"* ]]; then
    local checklist="${PROJECT_ROOT}/${base_dir}/.pipeline/code-review-checklist.json"
    local issues="${PROJECT_ROOT}/${base_dir}/.pipeline/integration-issues.json"
    if [[ -f "$checklist" ]]; then
      gate_context="${gate_context}

## [PRE-INJECTED] Code Review Checklist
\`\`\`json
$(jq -c '.' "$checklist")
\`\`\`"
    fi
    if [[ -f "$issues" ]]; then
      gate_context="${gate_context}

## [PRE-INJECTED] Integration Issues
\`\`\`json
$(jq -c '.' "$issues")
\`\`\`"
    fi
  fi

  echo "$gate_context"
}
