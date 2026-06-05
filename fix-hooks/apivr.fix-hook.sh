#!/usr/bin/env bash
# APIVR-Δ --fix-hook driver — Track B CONTROL.
# SAME model + budget as the Vivi treatment (VIVI_FIX_MODEL_CMD). The ONLY
# differences — which is exactly what the measurement isolates — are:
#   (1) APIVR-Δ's methodology (not Vivi's loop-native one);
#   (2) the NON-localized input (the raw last-output tail, as APIVR-Δ receives it).
# See RUNBOOK.md.
set -euo pipefail
: "${APIVR_DIR:?set APIVR_DIR to an APIVR-Δ checkout (the v3.6.x clone)}"
LAST="${EIDOLONS_SANDBOX_LAST_OUTPUT:-}"

PROMPT="$(cat "$APIVR_DIR/agent.md" "$APIVR_DIR/skills/methodology.md" 2>/dev/null)

## TEST OUTPUT (last lines)
$(cat "$LAST" 2>/dev/null || echo '(no output file)')

## TASK
Repair the implementation in the CURRENT working tree so the tests pass. Do NOT
edit the tests. Make a minimal, targeted edit and write it to the files in place."

# Identical model + budget to the Vivi side — the controlled variable.
: "${VIVI_FIX_MODEL_CMD:?set VIVI_FIX_MODEL_CMD (SAME model/budget as the Vivi side)}"
printf '%s\n' "$PROMPT" | eval "$VIVI_FIX_MODEL_CMD"
