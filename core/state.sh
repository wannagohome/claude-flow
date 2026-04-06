#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/state.sh — JSON State Management
# ═══════════════════════════════════════════════════════════════
# Provides atomic JSON read/write with file locking, status
# transitions, dependency resolution, and stage graph queries.
# All stage metadata is read dynamically from flow.json.
# ═══════════════════════════════════════════════════════════════

# ── File Locking ──

_lock_path() {
  # Lock files go to /tmp to avoid polluting the repo
  local hash
  hash=$(echo "$1" | md5 -q 2>/dev/null || echo "$1" | md5sum | cut -d' ' -f1)
  echo "/tmp/flow-lock-${hash}"
}

# ── JSON Read/Write ──

read_json() {
  (
    flock -s 200 2>/dev/null || true  # Shared lock for reads
    jq -r "$2" "$1" 2>/dev/null || echo ""
  ) 200>"$(_lock_path "$1")"
}

update_json() {
  local file="$1" query="$2"
  local tmp
  tmp=$(mktemp)

  # File lock to prevent race conditions during parallel execution
  (
    flock -x 200 2>/dev/null || true  # Graceful fallback if flock unavailable
    if jq "$query" "$file" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$file"
    else
      rm -f "$tmp"
      echo -e "${RED}Failed to update JSON: $query${NC}" >&2
      return 1
    fi
  ) 200>"$(_lock_path "$file")"
}

# ── Status Accessors ──

get_status() {
  read_json "$1" ".stages.\"$2\".status"
}

set_status() {
  update_json "$1" ".stages.\"$2\".status = \"$3\""
}

# ═══════════════════════════════════════════════════════════════
# Stage Graph Queries — read from flow.json dynamically
# ═══════════════════════════════════════════════════════════════

get_stage_order() {
  local flow_json="$1"
  read_json "$flow_json" '.stage_order[]'
}

get_stage_deps() {
  local flow_json="$1" stage="$2"
  read_json "$flow_json" ".stages.\"$stage\".deps // [] | join(\",\")"
}

get_stage_type() {
  local flow_json="$1" stage="$2"
  read_json "$flow_json" ".stages.\"$stage\".type"
}

get_stage_phase() {
  local flow_json="$1" stage="$2"
  read_json "$flow_json" ".stages.\"$stage\".phase"
}

# ═══════════════════════════════════════════════════════════════
# Dependency Resolution
# ═══════════════════════════════════════════════════════════════

deps_satisfied() {
  local flow_json="$1" stage="$2"
  local deps
  deps=$(get_stage_deps "$flow_json" "$stage")
  [[ -z "$deps" ]] && return 0

  IFS=',' read -ra dep_array <<< "$deps"
  for dep in "${dep_array[@]}"; do
    local status
    status=$(get_status "$flow_json" "$dep")
    # complete or skipped both satisfy
    if [[ "$status" != "complete" && "$status" != "skipped" && "$status" != "max_exceeded" ]]; then
      return 1
    fi
  done
  return 0
}

get_ready_stages() {
  local flow_json="$1"
  local ready=()
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")
    if [[ "$status" == "pending" ]] && deps_satisfied "$flow_json" "$stage"; then
      ready+=("$stage")
    fi
  done <<< "$(get_stage_order "$flow_json")"
  echo "${ready[*]:-}"
}

is_all_complete() {
  local flow_json="$1"
  local stage
  while IFS= read -r stage; do
    [[ -z "$stage" ]] && continue
    local status
    status=$(get_status "$flow_json" "$stage")
    if [[ "$status" != "complete" && "$status" != "skipped" && "$status" != "max_exceeded" ]]; then
      return 1
    fi
  done <<< "$(get_stage_order "$flow_json")"
  return 0
}
