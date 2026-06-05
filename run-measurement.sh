#!/usr/bin/env bash
# Vivi-vs-APIVR-Δ head-to-head measurement — Track B of the Vivi succession.
# Wraps `eidolons eval swe` TWICE — Vivi (treatment) + APIVR-Δ (control) — on the
# SAME holdout, SAME host, SAME budget; emits a head-to-head scorecard
# (resolved-rate + pass^k + per-task). `--smoke` validates the harness wiring with
# gold_fix (no model). A real run needs `--via <sandbox>` + the model-edit command
# wired into fix-hooks/*.sh (see RUNBOOK.md). Adapter, not engine.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NEXUS="${EIDOLONS_NEXUS:-}"
HOLDOUT="$HERE/holdout.example.yaml"
VIA=""; K=5; SMOKE=false; OUTD="$HERE/results"; ALLOW=false
MODEL_ID="${VIVI_MEASUREMENT_MODEL_ID:-unset}"

usage() { sed -n '2,8p' "$0"; cat <<EOF

Usage: run-measurement.sh --nexus <eidolons-repo> [--holdout F] [--via CMD]
                          [--k N] [--smoke] [--out DIR] [--model-id STR]
  --smoke      gold_fix wiring check (no model, bare host) — DO THIS FIRST
  --via CMD    sandbox wrapper (docker/gvisor/e2b) — required for a real run (R8-03)
  --k N        pass^k trials per task (default 5)
  --model-id   stamp the host model id into the scorecard (host-conditional)
EOF
}

while [[ $# -gt 0 ]]; do case "$1" in
  --holdout)  HOLDOUT="$2"; shift 2;;
  --nexus)    NEXUS="$2"; shift 2;;
  --via)      VIA="$2"; shift 2;;
  --k)        K="$2"; shift 2;;
  --smoke)    SMOKE=true; shift;;
  --allow-unsafe) ALLOW=true; shift;;
  --out)      OUTD="$2"; shift 2;;
  --model-id) MODEL_ID="$2"; shift 2;;
  -h|--help)  usage; exit 0;;
  *) echo "unknown option: $1 (see --help)" >&2; exit 2;;
esac; done

[[ -n "$NEXUS" ]] || { echo "set --nexus <path-to-eidolons> (or EIDOLONS_NEXUS)" >&2; exit 2; }
EIDO="$NEXUS/cli/eidolons"
[[ -f "$EIDO"     ]] || { echo "no eidolons CLI at $EIDO" >&2; exit 2; }
[[ -f "$HOLDOUT"  ]] || { echo "no holdout suite at $HOLDOUT" >&2; exit 2; }
mkdir -p "$OUTD"
VIVI_DIR="${VIVI_DIR:-$(cd "$HERE/../vivi" 2>/dev/null && pwd || true)}"

run_side() {  # $1=label  $2=driver
  local label="$1" driver="$2"; local extra=()
  if [[ "$SMOKE" != true ]]; then
    [[ -x "$driver" ]] || { echo "fix-hook not executable: $driver (chmod +x, and wire the model — RUNBOOK.md)" >&2; exit 2; }
    if   [[ -n "$VIA" ]];        then extra=(--fix-hook "$driver" --via "$VIA")
    elif [[ "$ALLOW" == true ]]; then extra=(--fix-hook "$driver" --allow-unsafe-host)
    else echo "a real run needs --via <sandbox-cmd> (R8-03) or --allow-unsafe-host (trusted tasks/model only)" >&2; exit 2; fi
  fi
  echo "→ $label  ($([[ "$SMOKE" == true ]] && echo 'SMOKE / gold_fix' || echo 'model-driven'))" >&2
  EIDOLONS_NEXUS="$NEXUS" VIVI_DIR="$VIVI_DIR" \
    bash "$EIDO" eval swe --suite-file "$HOLDOUT" --k "$K" "${extra[@]+"${extra[@]}"}" --json \
    > "$OUTD/$label.json" 2>"$OUTD/$label.log" || true
  [[ -s "$OUTD/$label.json" ]] || echo "  ! $label produced no scorecard (see $OUTD/$label.log)" >&2
}

run_side vivi  "$HERE/fix-hooks/vivi.fix-hook.sh"
run_side apivr "$HERE/fix-hooks/apivr.fix-hook.sh"

# ── Head-to-head scorecard ───────────────────────────────────────────────────
jq -n --slurpfile v "$OUTD/vivi.json" --slurpfile a "$OUTD/apivr.json" \
  --arg model "$MODEL_ID" --arg via "${VIA:-unsafe-host}" --argjson k "$K" --arg smoke "$SMOKE" '
  ($v[0] // {}) as $V | ($a[0] // {}) as $A |
  { measurement: "Vivi-vs-APIVR-Δ head-to-head (Track B)",
    mode: (if $smoke=="true"
           then "SMOKE — harness wiring only (gold_fix); NOT a capability number"
           else "model-driven" end),
    host_model: $model, isolation: $via, k: $k,
    vivi:  {resolved_rate:($V.resolved_rate//null), pass_k:($V.pass_k//null), resolved:($V.resolved//null), total:($V.total//null)},
    apivr: {resolved_rate:($A.resolved_rate//null), pass_k:($A.pass_k//null), resolved:($A.resolved//null), total:($A.total//null)},
    delta_resolved_rate: (($V.resolved_rate//0) - ($A.resolved_rate//0)),
    delta_pass_k:        (($V.pass_k//0)        - ($A.pass_k//0)),
    per_task: [ ($V.tasks // [])[] as $vt
                | (($A.tasks // []) | map(select(.id==$vt.id)) | .[0]) as $at
                | {id:$vt.id, vivi_resolved:$vt.resolved, apivr_resolved:($at.resolved//null),
                   vivi_runs:$vt.resolved_runs, apivr_runs:($at.resolved_runs//null)} ],
    caveat: "Report host-conditional (the loop gain belongs to the RL-trained host; Vivi exploits it). Budget-match both sides; the holdout must be contamination-screened. A real number requires --via + a model fix-hook on the private N=30 holdout."
  }' | tee "$OUTD/head-to-head.json"
