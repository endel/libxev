# endel/libxev

A fork of [mitchellh/libxev](https://github.com/mitchellh/libxev) for
[quic-zig](https://github.com/endel/quic-zig), and through it routez. It exists
to carry fixes while upstream reviews them. The aim is to run on upstream
again: everything carried here is an upstream PR.

## Rules

1. **Every change is an upstream PR.** A fix or feature gets its own branch,
   cut from upstream `main`, and that branch is the head of a PR on
   mitchellh/libxev. Nothing is carried that is not proposed upstream.
2. **libxev's own tests pass.** `fork/check.sh <branch>` runs what upstream CI
   runs, as far as a Mac with Docker can. It has to pass on the change's branch
   by itself, before the PR is opened, and on `quic-zig` before a pin moves.
   A new behaviour comes with a test that fails without it.
3. **`quic-zig` is generated, never edited.** It is upstream `main`, then every
   branch in [`fork/patches`](fork/patches) in order, then this file and
   `fork/`. `fork/rebuild.sh` builds it onto `quic-zig-next`; after
   `fork/check.sh quic-zig-next` passes, it becomes `quic-zig` and is tagged
   `quic-zig-YYYY-MM-DD`. quic-zig pins that tag's commit.
4. **`main` mirrors upstream.** Nothing is committed to it.
5. **`fork/patches` is the only list** of what is carried: branch, PR, and why.
   A PR's status lives on the PR.
6. **Overlapping changes are stacked, and said so.** When two touch the same
   code, the later branch sits on the earlier and its `fork/patches` line says
   which. Whichever merges upstream first, the other is rebased.
7. **Someone else's PR we need gets a branch here** (`pr-224`), so a rebuild
   never depends on a third party's repository.
8. **Nothing a pin names is deleted.** GitHub serves a pinned tarball by commit,
   and a commit no branch or tag reaches can be collected. Retire a branch or
   tag only once no pushed quic-zig references it.

## Carrying a change

1. Branch from upstream `main`; fix; add a test that fails without the fix.
2. `fork/check.sh <branch>`.
3. Push the branch here and open the upstream PR.
4. Add its line to `fork/patches`, then `fork/rebuild.sh` and
   `fork/check.sh quic-zig-next`.
5. Move `quic-zig` and tag it, push both, and move quic-zig's pin.

## Letting go of one

When a PR merges upstream, delete its line, rebuild, check, and move the pin.
When the list is empty, quic-zig pins upstream again and `quic-zig` is retired.
If upstream turns a change down, record here whether it was reworked or is
carried knowingly, and why.
