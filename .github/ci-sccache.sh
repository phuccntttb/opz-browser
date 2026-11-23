#!/usr/bin/env bash
# Compiler cache (sccache) on GitHub Actions (.github/workflows/release.yml).
# $SCCACHE_DIR is restored from and saved to the Actions cache, one entry per
# OS, so a run only recompiles what changed since the last saved run.
#   ci-sccache.sh stop        print sccache's stats and errors and stop its
#                             server, so $SCCACHE_DIR is idle while it is saved
#   ci-sccache.sh prune KEY   delete this ref's other sccache-<OS>- entries
#                             (an Actions cache holds 10 GB per repo; keeping
#                             one entry per OS stops one OS evicting another)
set -euo pipefail
[ -n "${GITHUB_ACTIONS:-}" ] || { echo "ci-sccache: only for GitHub Actions" >&2; exit 1; }

case "${1:-}" in
stop)
    . "$(dirname "$0")/../env.sh"
    s="$MOZBUILD_STATE_PATH/sccache/sccache"
    [ -x "$s" ] || s="$s.exe"
    if [ -x "$s" ]; then
        "$s" --stop-server || echo "ci-sccache: no sccache server running"
    else
        echo "ci-sccache: no sccache at $s"
    fi
    du -sh "$SCCACHE_DIR" || true
    if [ -s "${SCCACHE_ERROR_LOG:-}" ]; then
        echo "--- sccache errors (last 40 lines of $SCCACHE_ERROR_LOG)"
        tail -n 40 "$SCCACHE_ERROR_LOG"
    fi
    ;;
prune)
    key="${2:?usage: ci-sccache.sh prune KEY}"
    ids="$(gh cache list -R "$GITHUB_REPOSITORY" --ref "$GITHUB_REF" --key "sccache-$RUNNER_OS-" \
        --limit 100 --json id,key -q ".[] | select(.key != \"$key\") | .id")"
    for id in $ids; do
        gh cache delete "$id" -R "$GITHUB_REPOSITORY" && echo "ci-sccache: deleted cache $id"
    done
    ;;
*)
    echo "usage: ci-sccache.sh stop|prune KEY" >&2; exit 1 ;;
esac
