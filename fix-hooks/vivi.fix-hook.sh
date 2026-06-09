#!/usr/bin/env bash
# Vivi --fix-hook driver — Track B TREATMENT.
# Invoked by `eidolons sandbox loop` (via `eidolons eval swe`) on each FAILING
# iteration, inside the task workdir. Vivi's distinguishing inputs vs the control:
#   (1) LOCALIZED feedback ($EIDOLONS_SANDBOX_FEEDBACK — assertion + file:line +
#       full-log), not a raw tail;
#   (2) the loop-native methodology;
#   (3) FRESH context per call (no accumulated transcript).
# Keep the MODEL + BUDGET identical to the apivr control — that is the controlled
# comparison. See RUNBOOK.md.
set -euo pipefail
: "${VIVI_DIR:?set VIVI_DIR to the Vivi repo (e.g. .../agents/vivi)}"
FEEDBACK="${EIDOLONS_SANDBOX_FEEDBACK:-}"

PROMPT="$(cat "$VIVI_DIR/agent.md" "$VIVI_DIR/skills/loop-native.md" 2>/dev/null)

## LOCALIZED FEEDBACK (this iteration — fresh context; do NOT assume prior attempts)
$(cat "$FEEDBACK" 2>/dev/null || echo '(no feedback file)')

## TASK
Repair the implementation in the CURRENT working tree so the tests pass. Target the
reported file:line loci. Do NOT edit the anchoring tests. Make a minimal, targeted
edit and write it to the files in place.
$(if [ -n "${EIDOLONS_SANDBOX_CANDIDATE:-}" ]; then printf '%s\n' \
"## FANOUT CANDIDATE DISCIPLINE
You are INDEPENDENT candidate ${EIDOLONS_SANDBOX_CANDIDATE} of ${EIDOLONS_SANDBOX_FANOUT:-?}.
There is NO retry: produce ONE coherent, COMPLETE fix in this single shot.
Diversify by candidate index: candidate 1 = the most likely strategy; candidate 2 =
the runner-up strategy; candidate 3+ = a materially different decomposition.
Implement a GENERAL fix derived from the function's CONTRACT (its name, signature,
and description), never a special-case for the visible test inputs."; fi)"

# ── MODEL INVOCATION (host-specific — YOU wire this) ──────────────────────────
# VIVI_FIX_MODEL_CMD must read the prompt on stdin and EDIT the working-tree files
# in place. Examples:
#   export VIVI_FIX_MODEL_CMD='claude -p --allowedTools Edit,Write,Bash'
#   export VIVI_FIX_MODEL_CMD='python3 /path/to/your/api_edit.py'
# Use the SAME command for the apivr control (same model + budget).
: "${VIVI_FIX_MODEL_CMD:?set VIVI_FIX_MODEL_CMD to a headless model-edit command (RUNBOOK.md)}"
printf '%s\n' "$PROMPT" | eval "$VIVI_FIX_MODEL_CMD"
