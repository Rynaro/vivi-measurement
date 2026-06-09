# Track B — Vivi-vs-APIVR-Δ Measurement Runbook

The **gating evidence** of the APIVR-Δ → Vivi succession: a controlled head-to-head
that measures whether Vivi's loop-native methodology actually out-resolves the
APIVR-Δ control on the same tasks, host, and budget. This number gates Vivi v1.0 and
tests the reversal conditions (see `…/eidolons/DOSSIER-APIVR-OVERHAUL-2026-06.md` §6).
Until it exists, confidence stays at **0.62**.

> **Honest framing.** The harness is an *adapter*: the nexus owns the orchestration
> (`eidolons eval swe` → `eidolons sandbox loop`) and DELEGATES the model
> (`--fix-hook`) and isolation (`--via`). The model-driven runs are **yours**.

## Locked decisions (the two 1b GAPs)
- **Holdout:** **N = 30** tasks (floor 20 — report the actual N, never pad). Each =
  a **blind-selected, post-cutoff, test-backed** fix commit, reverted, oracle = the
  test that then fails. Mix **~40% nexus / 25% crystalium / 20% GAMBIT / 15% junction**;
  record difficulty (files/lines). PRIVATE (gitignored) → contamination-free.
- **Host:** a **single declared RL-trained frontier Claude model**, **identical** for
  Vivi + APIVR-Δ, **model-ID-stamped**, **budget-matched**, **pass^k** (default k=5),
  isolated via `--via`. Default driver Claude Sonnet + an Opus sensitivity subset.

## Files
- `run-measurement.sh` — runs `eidolons eval swe` twice (Vivi + APIVR-Δ) → `results/head-to-head.json`.
- `fix-hooks/vivi.fix-hook.sh` — TREATMENT driver (localized feedback + loop-native methodology + fresh context).
- `fix-hooks/apivr.fix-hook.sh` — CONTROL driver (raw tail + APIVR-Δ methodology); **same model/budget**.
- `build-task.sh` — turn a real fix commit into a self-contained task.
- `holdout.example.yaml` — the nexus smoke tasks, for wiring validation only.

## Procedure

**1 — Build the private holdout.** For each blind-selected fix commit:
```sh
./build-task.sh --repo /abs/path/to/<repo> --commit <sha> --test '<oracle test cmd>' >> holdout.yaml
# VERIFY each: test RED at <sha>^, GREEN after gold_fix. Keep ~30 to the locked mix.
eidolons eval swe --suite-file holdout.yaml --validate-suite   # shape check
```
Keep `holdout.yaml` PRIVATE (it is gitignored).

**2 — Wire the model (yours).** Set one headless model-edit command used by BOTH sides:
```sh
export VIVI_FIX_MODEL_CMD='claude -p --allowedTools Edit,Write,Bash'   # or your API harness
export VIVI_DIR=/abs/.../agents/vivi
export APIVR_DIR=/abs/.../apivr-delta-checkout            # the v3.6.x control
export VIVI_MEASUREMENT_MODEL_ID='claude-sonnet-4-6'      # stamped into the scorecard
chmod +x run-measurement.sh build-task.sh fix-hooks/*.sh
```

**3 — Smoke (wiring check, no model):**
```sh
./run-measurement.sh --nexus /abs/.../eidolons --smoke --k 2
# expect: both sides resolved_rate 1.0, delta 0 → the harness is wired correctly.
```

**4 — Real run (controlled, budget-matched, pass^k):**
```sh
./run-measurement.sh --nexus /abs/.../eidolons \
  --holdout holdout.yaml --via 'docker run --rm -v "$PWD":/w -w /w <img>' \
  --k 5 --model-id "$VIVI_MEASUREMENT_MODEL_ID"
# → results/head-to-head.json  (vivi vs apivr: resolved_rate, pass^k, per-task, deltas)
```
Repeat the locked Opus sensitivity run on a subset.

**5 — Report.** `results/head-to-head.json` is the deliverable. Report it
**host-conditional**; budget-match both sides; state N + the repo mix.

## Reversal conditions (from the plan §6)
- **Vivi ≤ APIVR-Δ on a loop-competent host** AND the gap attributes to the
  A/P/I methodology shape → the spine premise is wrong (reconsider).
- Otherwise Vivi banks the loop gain → proceed to Stage 3 (roster intake + crew
  recomposition + APIVR-Δ demotion).

## Caveats
- **Host-contingency:** the loop's gain belongs to the RL-trained host; Vivi
  *exploits* it, never manufactures it. A weak/loop-incompetent host will show
  little/negative delta — that is the documented APIVR-Δ-fallback regime, not a Vivi failure.
- **Contamination:** use only the team's post-cutoff commits; never commit the holdout.
- **Budget-match:** identical model, attempt cap, and k both sides — else the
  comparison is confounded.

## Stage 2 — discriminating run (fanout vs iterate vs control)

The resolved-rate tie (strong host) / loss (weak host) measured above cannot see
Vivi's value surfaces. Stage 2 measures them directly:

- **Suite:** `holdout.stage2.yaml` — 3 ADVERSARIAL tasks (visible test = few fixed
  cases → hardcode-tempting; a per-task SEALED holdout checks generalization;
  `resolved` = passed the holdout = a GENUINE fix) + 3 LONG-HORIZON tasks
  (coordinated two-file fix, multi-caller rename, two independent bugs).
- **Arms (budget-matched, 3 model calls each):** `vivi-fanout` (`--fanout 3`,
  the host-adaptive weak-host shape: independent fresh-context candidates,
  external selection) / `vivi-iterate` (`--max-attempts 4`, the classic loop —
  ablation) / `apivr` (`--max-attempts 4`, control).
- **Substrate gates equal for ALL arms:** `--require-red` + sealed holdouts. The
  measured variables are the methodology + the loop shape only.
- **Needs** a Stage-2-capable nexus checkout (`feat/coder-7.5-stage2-fanout`).

```sh
export VIVI_FIX_MODEL_CMD='claude -p --model <model> --allowedTools Edit,Write,Bash'
export VIVI_DIR=/abs/.../agents/vivi APIVR_DIR=/abs/.../agents/APIVR-Delta
./run-stage2.sh --nexus /abs/<stage2-checkout> --smoke          # wiring first
./run-stage2.sh --nexus /abs/<stage2-checkout> \
  --via 'docker run --rm -v "$PWD":/w -w /w alpine:3' \
  --k 1 --model-id <model-id> --out results/stage2-<tier>
# → results/stage2-<tier>/stage2-head-to-head.json (deltas + per-arm finals_summary)
```

Read `finals_summary."reward-hacked"` per arm — the anti-gaming discipline delta —
alongside `resolved_rate` (genuine fixes only, because holdout-gated).
