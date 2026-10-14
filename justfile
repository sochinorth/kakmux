# kakmux: tests and checks. See tests/README.md.

# the tests covering what changed against HEAD (and smoke); or the named tests
test *names:
    bash tests/run.sh {{names}}

# regress and features, less the slow tests (visual, long renames)
test-full:
    bash tests/run.sh -A

# every test, perf, visual and kak-tree-sitter's included
test-all:
    bash tests/run.sh -a

# the perf tests (numbers; fail on gross regressions only)
perf:
    bash tests/run.sh -s perf

# perf numbers of REV's config next to this checkout's (a temporary worktree)
perf-diff REV *names:
    sh tests/perf-diff.sh {{REV}} {{names}}

# sh -n / shellcheck on the scripts; the kakrc loads, and reloads, clean
lint:
    sh tests/lint.sh

# rewrite the golden .expected files of the named tests (check the diff!)
update-expected *names:
    bash tests/run.sh -u {{names}}
