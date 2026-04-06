#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# core/model.sh — Model Routing
# ═══════════════════════════════════════════════════════════════
# Selects the appropriate Claude model for each stage based on
# type (write/review/audit) and round number. Model names are
# read from flow.json config, not hardcoded.
#
# Cost optimization strategy:
#   Write stages: opus (complex generation)
#   Audit stages: opus (thorough read-only analysis)
#   Review stages: sonnet (checklist-based verification)
#   Review round >= escalation threshold: opus (convergence)
# ═══════════════════════════════════════════════════════════════

get_model() {
  local flow_json="$1" stage="$2" round="${3:-}"
  local type
  type=$(get_stage_type "$flow_json" "$stage")

  # Read model configuration from flow.json
  local write_model review_model audit_model escalation_model escalation_round
  write_model=$(read_json "$flow_json" '.config.models.write // "claude-opus-4-6"')
  review_model=$(read_json "$flow_json" '.config.models.review // "claude-sonnet-4-6"')
  audit_model=$(read_json "$flow_json" '.config.models.audit // "claude-opus-4-6"')
  escalation_model=$(read_json "$flow_json" '.config.models.escalation.model // "claude-opus-4-6"')
  escalation_round=$(read_json "$flow_json" '.config.models.escalation.after_round // 5')

  if [[ "$type" == "review" ]]; then
    # Escalate to stronger model after threshold rounds (convergence difficulty)
    if [[ -n "$round" && "$round" -ge "$escalation_round" ]]; then
      echo "$escalation_model"
    else
      echo "$review_model"
    fi
  elif [[ "$type" == "audit" ]]; then
    echo "$audit_model"
  else
    echo "$write_model"
  fi
}
