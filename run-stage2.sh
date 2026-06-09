#!/usr/bin/env bash
# Stage-2 discriminating measurement — three budget-matched arms on one suite.
#
#   vivi-fanout   TREATMENT  parallel-sample-and-select: --fanout 3 (3 fresh-
#                            context candidates, external selection; the weak-
#                            host shape from Vivi's host-adaptive methodology)
#   vivi-iterate  ABLATION   the classic loop shape: --max-attempts 4
#                            (= 3 fix-hook calls; budget-matched to fanout 3)
#   apivr         CONTROL    APIVR-Δ methodology + raw tail: --max-attempts 4
#
# All arms: SAME model command (VIVI_FIX_MODEL_CMD), SAME suite, SAME --k,
# --require-red (mechanical red gate, equal for all), and the suite's per-task
# SEALED holdouts (substrate gate, equal for all). What differs is exactly the
# methodology + the loop SHAPE — the variables under measurement.
# resolved = passed the sealed holdout = a GENUINE fix; finals_summary exposes
# reward-hacked counts per arm.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NEXUS="${EIDOLONS_NEXUS:-}"
SUITE="$HERE/holdout.stage2.yaml"
VIA=""; K=1; SMOKE=false; OUTD="$HERE/results/stage2"; ALLOW=false
ARMS="vivi-fanout,vivi-iterate,apivr"
FANOUT_N=3
MODEL_ID="${VIVI_MEASUREMENT_MODEL_ID:-unset}"

usage() { sed -n '2,17p' "$0"; cat <<EOF

Usage: run-stage2.sh --nexus <stage2-capable-eidolons-checkout>
                     [--suite F] [--via CMD] [--k N] [--smoke] [--out DIR]
                     [--arms CSV] [--fanout N] [--model-id STR] [--allow-unsafe]
  --smoke    gold_fix wiring check (no model) — DO THIS FIRST
  --arms     subset of: vivi-fanout,vivi-iterate,apivr (default: all three)
EOF
}

while [[ $# -gt 0 ]]; do case "$1" in
  --suite)    SUITE="$2"; shift 2;;
  --nexus)    NEXUS="$2"; shift 2;;
  --via)      VIA="$2"; shift 2;;
  --k)        K="$2"; shift 2;;
  --smoke)    SMOKE=true; shift;;
  --allow-unsafe) ALLOW=true; shift;;
  --out)      OUTD="$2"; shift 2;;
  --arms)     ARMS="$2"; shift 2;;
  --fanout)   FANOUT_N="$2"; shift 2;;
  --model-id) MODEL_ID="$2"; shift 2;;
  -h|--help)  usage; exit 0;;
  *) echo "unknown option: $1 (see --help)" >&2; exit 2;;
esac; done

[[ -n "$NEXUS" ]] || { echo "set --nexus <path-to-stage2-capable-eidolons>" >&2; exit 2; }
EIDO="$NEXUS/cli/eidolons"
[[ -f "$EIDO"  ]] || { echo "no eidolons CLI at $EIDO" >&2; exit 2; }
[[ -f "$SUITE" ]] || { echo "no suite at $SUITE" >&2; exit 2; }
grep -q -- '--fanout' "$NEXUS/cli/src/eval_swe.sh" 2>/dev/null \
  || { echo "--nexus checkout lacks Stage-2 eval flags (need feat/coder-7.5-stage2-fanout)" >&2; exit 2; }
mkdir -p "$OUTD"
VIVI_DIR="${VIVI_DIR:-$(cd "$HERE/../vivi" 2>/dev/null && pwd || true)}"

run_arm() {  # $1=arm-label  $2=driver  $3...=extra eval-swe args
  local label="$1" driver="$2"; shift 2
  local extra=("$@")
  if [[ "$SMOKE" != true ]]; then
    [[ -x "$driver" ]] || { echo "fix-hook not executable: $driver" >&2; exit 2; }
    if   [[ -n "$VIA" ]];        then extra+=(--fix-hook "$driver" --via "$VIA")
    elif [[ "$ALLOW" == true ]]; then extra+=(--fix-hook "$driver" --allow-unsafe-host)
    else echo "a real run needs --via <sandbox-cmd> (R8-03) or --allow-unsafe" >&2; exit 2; fi
  fi
  echo "→ arm: $label  ($([[ "$SMOKE" == true ]] && echo 'SMOKE / gold_fix' || echo 'model-driven'))" >&2
  EIDOLONS_NEXUS="$NEXUS" VIVI_DIR="$VIVI_DIR" \
    bash "$EIDO" eval swe --suite-file "$SUITE" --k "$K" --require-red \
    "${extra[@]+"${extra[@]}"}" --json \
    > "$OUTD/$label.json" 2>"$OUTD/$label.log" || true
  [[ -s "$OUTD/$label.json" ]] || echo "  ! $label produced no scorecard (see $OUTD/$label.log)" >&2
}

case ",$ARMS," in *",vivi-fanout,"*)
  run_arm vivi-fanout  "$HERE/fix-hooks/vivi.fix-hook.sh"  --fanout "$FANOUT_N" ;; esac
case ",$ARMS," in *",vivi-iterate,"*)
  run_arm vivi-iterate "$HERE/fix-hooks/vivi.fix-hook.sh"  --max-attempts 4 ;; esac
case ",$ARMS," in *",apivr,"*)
  run_arm apivr        "$HERE/fix-hooks/apivr.fix-hook.sh" --max-attempts 4 ;; esac

# ── Combined scorecard ────────────────────────────────────────────────────────
emit_side() { [[ -s "$OUTD/$1.json" ]] && cat "$OUTD/$1.json" || echo '{}'; }
jq -n \
  --argjson vf "$(emit_side vivi-fanout)" \
  --argjson vi "$(emit_side vivi-iterate)" \
  --argjson ap "$(emit_side apivr)" \
  --arg model "$MODEL_ID" --arg via "${VIA:-unsafe-host}" --argjson k "$K" \
  --arg smoke "$SMOKE" --argjson fanout "$FANOUT_N" '
  def side(s): {resolved_rate:(s.resolved_rate//null), pass_k:(s.pass_k//null),
                resolved:(s.resolved//null), total:(s.total//null),
                finals_summary:(s.finals_summary//{})};
  { measurement: "Stage-2 discriminating run — fanout (treatment) vs iterate (ablation) vs APIVR-Δ (control)",
    mode: (if $smoke=="true" then "SMOKE — wiring only (gold_fix); NOT a capability number" else "model-driven" end),
    host_model: $model, isolation: $via, k: $k, fanout: $fanout,
    budget_note: "fanout 3 = 3 model calls; iterate/apivr --max-attempts 4 = up to 3 fix-hook calls — budget-matched",
    vivi_fanout:  side($vf),
    vivi_iterate: side($vi),
    apivr:        side($ap),
    delta_fanout_vs_apivr:   ((($vf.resolved_rate)//0) - (($ap.resolved_rate)//0)),
    delta_fanout_vs_iterate: ((($vf.resolved_rate)//0) - (($vi.resolved_rate)//0)),
    delta_iterate_vs_apivr:  ((($vi.resolved_rate)//0) - (($ap.resolved_rate)//0)),
    per_task: [ ($vf.tasks // [])[] as $t
                | (($vi.tasks // []) | map(select(.id==$t.id)) | .[0]) as $i
                | (($ap.tasks // []) | map(select(.id==$t.id)) | .[0]) as $a
                | {id:$t.id,
                   fanout:{resolved:$t.resolved, finals:$t.finals},
                   iterate:{resolved:($i.resolved//null), finals:($i.finals//null)},
                   apivr:{resolved:($a.resolved//null), finals:($a.finals//null)}} ],
    caveat: "resolved = passed the SEALED holdout (genuine fix). Host-conditional; budget-matched; report the host model id. Small-N constructed suite — directional, not definitive."
  }' | tee "$OUTD/stage2-head-to-head.json"
