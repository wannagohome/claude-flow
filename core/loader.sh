#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/loader.sh — YAML Parsing + Module Discovery + DAG Synthesis
# ═══════════════════════════════════════════════════════════════
# Reads flow.yaml, resolves presets via deep merge, discovers
# modules and providers from multiple sources (project local,
# npm packages, built-in), and synthesizes all module stages
# into a single DAG with proper dependency resolution.
#
# This is the bridge between declarative YAML configuration
# and the runtime flow.json state file.
# ═══════════════════════════════════════════════════════════════

# ── flow.yaml Discovery ──

find_flow_yaml() {
  local search_dir="${1:-$PROJECT_ROOT}"
  local flow_yaml="${search_dir}/.claude/flow.yaml"
  if [[ -f "$flow_yaml" ]]; then
    echo "$flow_yaml"
  else
    echo ""
  fi
}

# ── Preset Resolution + Deep Merge ──

resolve_flow_config() {
  local flow_yaml="$1"
  local extends
  extends=$(yq '.extends // ""' "$flow_yaml")

  local base_config=""
  if [[ -n "$extends" && "$extends" != "null" ]]; then
    local preset_path
    preset_path=$(resolve_preset_path "$extends")
    if [[ -n "$preset_path" && -f "$preset_path" ]]; then
      base_config="$preset_path"
    else
      echo -e "${YELLOW}⚠ Preset not found: ${extends}${NC}" >&2
    fi
  fi

  if [[ -n "$base_config" ]]; then
    # Deep merge: preset + user config (user wins)
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$base_config" "$flow_yaml"
  else
    cat "$flow_yaml"
  fi
}

# ── Preset Path Resolution ──

resolve_preset_path() {
  local name="$1"

  # Local path (absolute or relative)
  if [[ -f "$name" ]]; then echo "$name"; return; fi
  if [[ -f "${PROJECT_ROOT}/$name" ]]; then echo "${PROJECT_ROOT}/$name"; return; fi

  # Built-in preset
  local builtin="${FLOW_HOME}/presets/${name}.yaml"
  if [[ -f "$builtin" ]]; then echo "$builtin"; return; fi

  # npm package
  local npm_pkg="${PROJECT_ROOT}/node_modules/claude-flow-preset-${name}/preset.yaml"
  if [[ -f "$npm_pkg" ]]; then echo "$npm_pkg"; return; fi

  echo ""
}

# ── Module Directory Resolution ──

resolve_module_dir() {
  local name="$1"

  # 1. Project local
  local local_dir="${PROJECT_ROOT}/.claude/flow/modules/${name}"
  [[ -d "$local_dir" ]] && echo "$local_dir" && return

  # 2. npm package
  local npm_dir="${PROJECT_ROOT}/node_modules/claude-flow-module-${name}"
  [[ -d "$npm_dir" ]] && echo "$npm_dir" && return

  # 3. Built-in
  local builtin_dir="${FLOW_HOME}/modules/${name}"
  [[ -d "$builtin_dir" ]] && echo "$builtin_dir" && return

  echo ""
}

# ═══════════════════════════════════════════════════════════════
# DAG Synthesis — Build Stage Graph from Modules
# ═══════════════════════════════════════════════════════════════

build_stage_graph() {
  local merged_config="$1"  # resolved config tempfile

  local stages_json="{}"
  local stage_order="[]"

  # Iterate phases in order
  local phases
  phases=$(yq '.phases | keys | .[]' "$merged_config" 2>/dev/null)

  local phase_index=0
  local prev_phase_last_stage=""

  for phase in $phases; do
    local strategy modules skip manual_gate

    strategy=$(yq ".phases.${phase}.strategy // \"\"" "$merged_config")
    skip=$(yq ".phases.${phase}.skip // false" "$merged_config")
    manual_gate=$(yq ".phases.${phase}.manual_gate // true" "$merged_config")

    [[ "$skip" == "true" ]] && continue

    # strategy -> module name conversion (for spec phase)
    if [[ -n "$strategy" && "$strategy" != "null" && "$strategy" != "" ]]; then
      modules="$strategy"
    else
      modules=$(yq ".phases.${phase}.modules // [] | .[]" "$merged_config")
    fi

    if [[ -z "$modules" ]]; then
      echo -e "${YELLOW}⚠ No modules configured for phase: ${phase}${NC}" >&2
      continue
    fi

    for module_name in $modules; do
      local module_dir
      module_dir=$(resolve_module_dir "$module_name")
      if [[ -z "$module_dir" ]]; then
        echo -e "${RED}Module not found: ${module_name}${NC}" >&2
        return 1
      fi

      local module_yaml="${module_dir}/module.yaml"
      if [[ ! -f "$module_yaml" ]]; then
        echo -e "${RED}module.yaml not found in: ${module_dir}${NC}" >&2
        return 1
      fi

      # Iterate stages in module
      local stage_count
      stage_count=$(yq '.stages | length' "$module_yaml")

      for i in $(seq 0 $((stage_count - 1))); do
        local name type prompt deps_raw script handler
        name=$(yq ".stages[$i].name" "$module_yaml")
        type=$(yq ".stages[$i].type" "$module_yaml")
        prompt=$(yq ".stages[$i].prompt // \"\"" "$module_yaml")
        deps_raw=$(yq ".stages[$i].deps // [] | .[]" "$module_yaml")
        script=$(yq ".stages[$i].script // \"\"" "$module_yaml")
        handler=$(yq ".stages[$i].handler // \"\"" "$module_yaml")

        # Resolve prompt to absolute path
        local prompt_path=""
        if [[ -n "$prompt" && "$prompt" != "null" && "$prompt" != "" ]]; then
          prompt_path="${module_dir}/${prompt}"
        fi

        # Resolve gate script to absolute path
        local script_path=""
        if [[ -n "$script" && "$script" != "null" && "$script" != "" ]]; then
          script_path="${module_dir}/${script}"
        fi

        # Resolve handler (empty string if not set)
        if [[ "$handler" == "null" ]]; then
          handler=""
        fi

        # Build deps array: module-internal names stay as-is, module::stage for cross-module
        local deps_array="[]"
        for dep in $deps_raw; do
          deps_array=$(echo "$deps_array" | jq --arg d "$dep" '. += [$d]')
        done

        # Phase boundary dependency: first stage of module depends on last stage of previous phase
        if [[ $i -eq 0 && -n "$prev_phase_last_stage" ]]; then
          local has_deps
          has_deps=$(echo "$deps_array" | jq 'length')
          if [[ "$has_deps" -eq 0 ]]; then
            deps_array=$(echo "$deps_array" | jq --arg d "$prev_phase_last_stage" '. += [$d]')
          fi
        fi

        # Add stage to JSON
        stages_json=$(echo "$stages_json" | jq \
          --arg name "$name" \
          --arg type "$type" \
          --arg phase "$phase" \
          --arg module "$module_name" \
          --arg prompt_path "$prompt_path" \
          --arg script_path "$script_path" \
          --arg handler "$handler" \
          --argjson deps "$deps_array" \
          '.[$name] = {
            "status": "pending",
            "type": $type,
            "phase": $phase,
            "module": $module,
            "prompt_path": $prompt_path,
            "script_path": $script_path,
            "handler": $handler,
            "deps": $deps
          } + (if $type == "review" then {"rounds": []} else {} end)')

        stage_order=$(echo "$stage_order" | jq --arg s "$name" '. += [$s]')
      done
    done

    # Insert manual gate at phase boundary
    if [[ "$manual_gate" == "true" ]]; then
      local gate_name="manual-review-${phase}"
      local last_stage
      last_stage=$(echo "$stage_order" | jq -r '.[-1] // ""')

      stages_json=$(echo "$stages_json" | jq \
        --arg name "$gate_name" \
        --arg phase "$phase" \
        --argjson deps "[\"$last_stage\"]" \
        '.[$name] = {
          "status": "pending",
          "type": "manual",
          "phase": $phase,
          "module": "",
          "prompt_path": "",
          "script_path": "",
          "handler": "",
          "deps": $deps
        }')

      stage_order=$(echo "$stage_order" | jq --arg s "$gate_name" '. += [$s]')
    fi

    # Track last stage of this phase for cross-phase deps
    prev_phase_last_stage=$(echo "$stage_order" | jq -r '.[-1] // ""')
    phase_index=$((phase_index + 1))
  done

  echo "$stages_json" | jq --argjson order "$stage_order" '{stages: ., stage_order: $order}'
}

# ═══════════════════════════════════════════════════════════════
# flow.json Generation (called by cmd_init)
# ═══════════════════════════════════════════════════════════════

generate_flow_json() {
  local feature="$1" base_dir="$2" flow_yaml="$3" output="$4"
  shift 4
  local extra_flags=("$@")

  # Merge config (preset + user)
  local merged_config
  merged_config=$(mktemp)
  resolve_flow_config "$flow_yaml" > "$merged_config"

  # Apply extra flags to merged config
  for flag in "${extra_flags[@]}"; do
    case "$flag" in
      --skip-design)
        # Mark design phase as skipped
        yq -i '.phases.design.skip = true' "$merged_config" 2>/dev/null || true
        ;;
    esac
  done

  # Build stage graph from all active modules
  local graph_json
  graph_json=$(build_stage_graph "$merged_config")
  if [[ $? -ne 0 || -z "$graph_json" ]]; then
    echo -e "${RED}Failed to build stage graph${NC}" >&2
    rm -f "$merged_config"
    return 1
  fi

  local slug date
  slug=$(echo "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  date=$(date +%Y-%m-%d)

  # Collect config sections from merged YAML
  local providers_config
  providers_config=$(yq '.providers // {}' "$merged_config" | yq -o json 2>/dev/null || echo '{}')

  local test_config
  test_config=$(yq '.test // {}' "$merged_config" | yq -o json 2>/dev/null || echo '{}')

  local models_config
  models_config=$(yq '.models // {}' "$merged_config" | yq -o json 2>/dev/null || echo '{}')

  local review_config
  review_config=$(yq '.review // {}' "$merged_config" | yq -o json 2>/dev/null || echo '{}')

  # Conventions path resolution
  local conventions_path
  conventions_path=$(yq '.project.conventions // ""' "$merged_config")
  if [[ -n "$conventions_path" && "$conventions_path" != "null" && "$conventions_path" != "" ]]; then
    # Relative path -> absolute path (relative to .claude/)
    if [[ "$conventions_path" != /* ]]; then
      conventions_path="${PROJECT_ROOT}/.claude/${conventions_path}"
    fi
  else
    conventions_path=""
  fi

  # Extract stages and stage_order from graph
  local stages stage_order
  stages=$(echo "$graph_json" | jq '.stages')
  stage_order=$(echo "$graph_json" | jq '.stage_order')

  # Assemble final flow.json
  jq -n \
    --arg feature "$feature" \
    --arg slug "$slug" \
    --arg date "$date" \
    --arg base_dir "$base_dir" \
    --arg conventions_path "$conventions_path" \
    --argjson stages "$stages" \
    --argjson stage_order "$stage_order" \
    --argjson providers "$providers_config" \
    --argjson test "$test_config" \
    --argjson models "$models_config" \
    --argjson review "$review_config" \
    '{
      feature: $feature,
      feature_slug: $slug,
      created: $date,
      base_dir: $base_dir,
      config: {
        conventions_path: $conventions_path,
        models: $models,
        review: $review,
        test: $test,
        providers: $providers
      },
      stage_order: $stage_order,
      stages: $stages
    }' > "$output"

  rm -f "$merged_config"
  echo -e "${DIM}  Generated: ${output}${NC}"
}
