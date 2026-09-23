#!/bin/bash
# Runs what libxev's own CI runs, as far as one Mac with Docker can: the tests
# natively (kqueue) and on Linux (epoll and io_uring), the examples and
# benchmarks, and a build for every CI target. Nothing is carried on quic-zig or
# proposed upstream until this passes, both on its own branch and on quic-zig.
#
#   fork/check.sh <branch-or-commit>
#
# Linux runs in Docker (LINUX_IMAGE, default routez-bench: any image with the
# Zig in build.zig.zon) with seccomp relaxed, because the default profile
# blocks io_uring. Windows and x86_64 are only built here; upstream CI runs
# their tests on the PR. Upstream's `nix flake check` is not run.
set -euo pipefail

main() {
    local rev=${1:?usage: fork/check.sh <branch-or-commit>}
    local image=${LINUX_IMAGE:-routez-bench}
    # Globals: the EXIT trap runs after main has returned.
    repo=$(cd "$(dirname "$0")/.." && pwd)
    tmp=$(mktemp -d)
    trap 'git -C "$repo" worktree remove --force "$tmp/src" > /dev/null 2>&1; rm -rf "$tmp"' EXIT
    git -C "$repo" worktree add -q --detach "$tmp/src" "$rev"
    cd "$tmp/src"
    echo "$rev ($(git rev-parse --short HEAD))"

    # A fresh cache: a shared one has reported a stale pass.
    export ZIG_LOCAL_CACHE_DIR="$tmp/cache"
    step "tests, $(uname -s) $(uname -m)" zig build test --summary all
    step "examples and benchmarks" zig build -Demit-example -Demit-bench --summary all
    local t
    for t in aarch64-linux-gnu aarch64-linux-musl x86_64-linux-gnu x86_64-linux-musl \
        aarch64-macos x86_64-macos x86_64-windows-gnu; do
        step "build $t" zig build -Dtarget="$t"
    done
    step "tests, Linux $(docker run --rm "$image" uname -m)" docker run --rm \
        --security-opt seccomp=unconfined -v "$tmp/src:/src:ro" "$image" \
        bash -c 'cp -r /src /w && cd /w && zig build test --summary all'
    echo "all checks passed"
}

step() {
    local name=$1
    shift
    printf '  %-34s' "$name"
    if "$@" > "$tmp/log" 2>&1; then
        echo "ok  $(grep -oE '[0-9]+ pass[^)]*\)' "$tmp/log" | tail -1)"
    else
        echo FAILED
        tail -n 25 "$tmp/log"
        exit 1
    fi
}

main "$@"
exit
