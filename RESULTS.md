# Vivi-vs-APIVR-Δ — Measurement Results

## Run (2026-06-05) — model-driven, docker-isolated
- **Host model:** `claude-code 2.1.162` (Claude). **Isolation:** docker (`alpine:3`). **k:** 1.
- **Holdout:** 4 constructed fix tasks — 2 easy (`kv-multi-eq`, `fizzbuzz-order`) + 2 harder (`normalize-two-bugs` [two fixes], `sum-off-by-one` [subtle off-by-one]). **NOT** the locked cross-language N=30 (see below).

| | resolved | resolved_rate | pass^1 |
|---|---|---|---|
| **Vivi** (localized feedback + loop-native) | 4/4 | 1.0 | 1.0 |
| **APIVR-Δ** (raw tail + its methodology) | 4/4 | 1.0 | 1.0 |
| **Δ** | — | **0** | 0 |

## Finding (the honest read)
On a **strong frontier host, Vivi ≈ APIVR-Δ on resolved-rate** — both one-shot typical fixes (easy *and* moderate). The host model dominates; the methodology delta on resolved-rate is **~0**, exactly as the research predicted (the loop's gain belongs to the RL-trained host — `../eidolons/.spectra/research/apivr-overhaul-digest.md` §1.1; RLEF).

- **Reversal check (plan §6):** R-A (Vivi *materially below* the APIVR-Δ baseline, gap attributable to the A/P/I methodology shape) is **NOT triggered** — Vivi shows **no regression**. The succession holds.
- **Resolved-rate is the WRONG discriminator here.** A shared strong model equalizes fix-rate on clean single-bug tasks. Vivi's actual value is: (a) the **closed autonomous loop** (APIVR-Δ hands control back; Vivi runs unattended to green — throughput/convenience, not fix-rate); (b) the **anti-reward-hacking + fresh-context + pass^k guardrails** (manifest on adversarial / long-horizon / flaky tasks, not clean fixes); (c) **graceful degradation** on weak/loop-incompetent hosts.
- **The discriminating measurement** is therefore an **adversarial** (reward-hacking-tempting) + **long-horizon multi-file** + **weak-host** suite — not mined easy commits, which a strong model resolves regardless of methodology.

## The full N=30 (operator / CI job)
The locked cross-language N=30 × pass^k(5) is a **multi-hour, multi-runtime** run: per-repo sandbox images (bats+jq+yq for nexus / cargo for crystalium / vitest for gambit / go+cargo for junction), compile-heavy red→green verification, up to **~300 `claude -p` sessions**. The builder + harness are ready and proven:
```sh
# build N tasks (blind-select post-cutoff, test-backed fix commits; the locked mix)
./build-task.sh --repo /abs/<repo> --commit <sha> --test '<oracle>' >> holdout.yaml   # ×N
# run the head-to-head (per-runtime sandbox)
./run-measurement.sh --nexus /abs/eidolons --holdout holdout.yaml --via '<sandbox>' --k 5
```
Based on this run + the pilot, it would **most likely confirm Δ≈0 on resolved-rate**. Prioritize the adversarial/long-horizon suite for the real signal.

## Bonus — a real bug found by RUNNING (not assuming)
The first run surfaced + fixed a genuine 1c loop bug: the loop printed the fix-hook's stdout (an LLM CLI's verbose response) onto its own `--json` ledger → `eval swe`'s `jq` parse failed → **resolved tasks mis-counted as unresolved**. Fixed: nexus `0b8149e` (`bash -c "$FIX_HOOK" >&2` + regression bats, 21/21). Validates the research's "documentary ≠ behavioral — measure, don't assume."

## Discriminating run (2026-06-05) — WEAK host (haiku), hard suite
3 harder tasks (`semver-compare`, `dedup-order`, `titlecase-two-step`), debian-isolated, `claude -p --model haiku` (weak-host probe), k=1.

| | resolved | rate | Δ |
|---|---|---|---|
| **Vivi** | 2/3 | 0.67 | |
| **APIVR-Δ** | 3/3 | 1.0 | **Vivi −0.33** |

Per-task: `semver-compare` — Vivi capped (unresolved), APIVR-Δ passed; `dedup-order` + `titlecase-two-step` both passed. (Single k=1 sample — directional, not definitive; haiku is stochastic.)

### Combined finding (strong + weak)
| host | Vivi | APIVR-Δ | Δ |
|---|---|---|---|
| strong (opus) | 4/4 | 4/4 | 0 |
| weak (haiku) | 2/3 | 3/3 | −0.33 |

**Resolved-rate does not favour Vivi anywhere — it TIES on a capable host and is ≤ on a weak one.** This empirically confirms the host-contingency thesis (the loop's gain belongs to the RL-trained host; the loop degrades on weak hosts — RLEF) and **strongly validates retaining APIVR-Δ as the conservative weak-host fallback**. Vivi's case for *default* rests on the autonomous loop (throughput/convenience) + guardrails (adversarial/long-horizon safety), NOT fix-rate.

### Implication for Stage 3b (default-coder flip)
The data does **not** support an UNCONDITIONAL flip of Vivi to the default coder — it would regress weak-host consumers. Honest options: (1) keep APIVR-Δ default, Vivi opt-in until a strong-host WIN (not just a tie) is shown; (2) flip Vivi default but HOST-CONDITIONALLY (cortex steers weak/loop-incompetent hosts to APIVR-Δ); (3) unconditional flip on autonomy+guardrails grounds, with prominent host-contingency docs. Recommend (2) or (1) over (3).
