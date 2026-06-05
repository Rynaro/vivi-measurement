#!/usr/bin/env bash
# build-task.sh — emit a self-contained holdout task from a real fix commit.
# No network at run time: setup LOCAL-clones the repo and checks out the fix's
# PARENT (the broken state); gold_fix re-applies the fix's touched files (the
# held-out reference answer). The test command is the oracle: it must be RED at
# the parent and GREEN after gold_fix — VERIFY that before trusting the task.
#
# Usage:
#   build-task.sh --repo <abs-git-dir> --commit <sha> --test '<cmd>' [--id ID] >> holdout.yaml
#
# Curation policy (locked, RUNBOOK.md): N=30 (floor 20); BLIND-select post-cutoff,
# test-backed fix commits; mix ~40% nexus / 25% crystalium / 20% GAMBIT / 15%
# junction; record difficulty (files/lines). The repo stays local & PRIVATE
# (gitignored) — that is what keeps the holdout contamination-free.
set -euo pipefail
REPO=""; COMMIT=""; TEST=""; ID=""
while [[ $# -gt 0 ]]; do case "$1" in
  --repo)   REPO="$(cd "$2" 2>/dev/null && pwd || echo "$2")"; shift 2;;
  --commit) COMMIT="$2"; shift 2;;
  --test)   TEST="$2"; shift 2;;
  --id)     ID="$2"; shift 2;;
  *) echo "unknown option: $1" >&2; exit 2;;
esac; done
[[ -d "$REPO/.git" ]] || { echo "--repo must be an absolute path to a git repo" >&2; exit 2; }
[[ -n "$COMMIT" && -n "$TEST" ]] || { echo "need --commit <sha> and --test '<cmd>'" >&2; exit 2; }
short="$(git -C "$REPO" rev-parse --short "$COMMIT")" || { echo "bad commit: $COMMIT" >&2; exit 2; }
ID="${ID:-$(basename "$REPO")-$short}"
files="$(git -C "$REPO" show --pretty=format: --name-only "$COMMIT" | grep -v '^$' | tr '\n' ' ')"
[[ -n "$files" ]] || { echo "commit $short touches no files" >&2; exit 2; }
nlines="$(git -C "$REPO" show --numstat --pretty=format: "$COMMIT" | awk '{a+=$1+$2} END{print a+0}')"

cat <<EOF
  - id: ${ID}
    description: "reverted fix ${short} in $(basename "$REPO") ($(echo $files | wc -w | tr -d ' ') files / ${nlines} lines); oracle = the listed test"
    setup: |
      git clone -q "${REPO}" . 2>/dev/null
      git -c advice.detachedHead=false checkout -q ${COMMIT}^ 2>/dev/null
      git config user.email t@example.com && git config user.name tester
    test: |
      ${TEST}
    gold_fix: |
      git checkout ${COMMIT} -- ${files}
EOF
echo "# built '${ID}' (${files}— ${nlines} lines). VERIFY: test RED at ${short}^, GREEN after gold_fix; then blind-keep or discard." >&2
