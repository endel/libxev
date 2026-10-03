#!/bin/bash
# Rebuilds the integration branch from scratch: upstream main, then each branch
# in fork/patches in order, then fork/ itself. The result lands on
# `quic-zig-next`; moving `quic-zig` and tagging it are left to a person, once
# fork/check.sh passes on it.
#
#   fork/rebuild.sh            (from any branch with fork/ in it)
#
# UPSTREAM_REMOTE (default origin) and FORK_REMOTE (default endel) name the
# remotes. A branch that exists locally is used over the fork's copy, so a
# patch can be tried before it is pushed.
set -euo pipefail

main() {
    cd "$(dirname "$0")/.."
    local up=${UPSTREAM_REMOTE:-origin} fork=${FORK_REMOTE:-endel}
    [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit or stash first" >&2; exit 1; }

    # Switching to upstream removes fork/ from the tree, this script included.
    # Global: the EXIT trap runs after main has returned.
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cp -R fork FORK.md "$tmp/"

    git fetch -q "$up"
    git fetch -q "$fork"
    local base; base=$(git rev-parse "$up/main")
    git switch -q -C quic-zig-next "$base"

    local branch pr why tip commits
    while read -r branch pr why; do
        case "$branch" in '' | '#'*) continue ;; esac
        tip=$(git rev-parse -q --verify "refs/heads/$branch" ||
            git rev-parse -q --verify "refs/remotes/$fork/$branch") ||
            { echo "$branch: not found locally or on $fork" >&2; exit 1; }
        # What the branch has that is not applied yet: a branch stacked on an
        # earlier one brings that one's commits along, and these skip them.
        commits=$(git rev-list --reverse --right-only --cherry-pick --no-merges "HEAD...$tip")
        echo "$branch ($pr): $(echo "$commits" | grep -c .) commit(s)"
        # -x records where each commit came from.
        [ -z "$commits" ] || git cherry-pick -x $commits > /dev/null
    done < "$tmp/fork/patches"

    cp -R "$tmp/fork" "$tmp/FORK.md" .
    git add fork FORK.md
    git commit -q -m "fork: what this branch carries and how it is built"
    echo
    echo "quic-zig-next = upstream $(git rev-parse --short "$base") + the above."
    echo "Next: fork/check.sh quic-zig-next, then"
    echo "      git branch -f quic-zig quic-zig-next && git tag quic-zig-$(date +%Y-%m-%d) quic-zig"
}

main "$@"
exit
