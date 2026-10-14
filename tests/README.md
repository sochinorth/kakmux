# tests

End-to-end tests of the config: real kak sessions in private tmux servers,
driven with `kak -p` and `tmux send-keys`, with clangd, kak-lsp and
kak-tree-sitter running. One line per test, PASS / FAIL / SKIP; non-zero exit
on any failure.

```sh
just test                  # the tests covering what changed against HEAD, and smoke
just test -c trunk         # ... what changed against trunk (a branch's work)
just test smoke rename     # some tests, by name (or a category: just test regress)
just test-full             # regress + features, less the slow ones
just test-all              # everything: + slow, perf, visual, kts
just perf                  # perf numbers, fail on gross regressions only
just perf-diff trunk~3     # perf numbers of another revision's config next to these
just lint                  # sh -n/shellcheck, kakrc loads and reloads clean
just update-expected NAME  # rewrite NAME's golden file from a run (read the diff)
bash tests/run.sh -h       # -k keep run dirs, -v show output, -j N at once
```

## Layout

| Dir | What | In `just test-full` |
| --- | --- | --- |
| `regress/` | Bugs fixed once: diagnostics routing, gutter, splits, rename, reload, smoke flows | yes (less `slow`) |
| `features/` | Features end to end: pickers, palette, explorer, jump labels, status line | yes (less `slow`) |
| `perf/` | Shells per key, idle, startup, hook time, big files, long sessions | no (`just perf`) |
| `visual/` | Screen sampled while typing (jitter), edits around inline diagnostics | no (slow) |
| `kts/` | kak-tree-sitter 3.2.2 server bugs, fixed in the patched package | no (`test-all`) |
| `lib/` | `h.sh` (harness), `fixtures.sh` (projects), `norm.sh`, `frames.py`, shell wrappers, fake tmux | |

## Which tests run

`just test` (`run.sh` with no names) runs the tests that cover what changed
against HEAD (`git diff HEAD`, untracked files too; `-c REF` against REF),
and `regress/smoke` always. Each test says what it covers in a header line,
paths from the repo root, globs allowed:

```sh
# covers: rc/splits.kak bin/kakmux-even kakmux.conf
```

A test whose own file (`NAME.sh`, `NAME.expected`) changed runs too; a change
to `tests/lib/` or `run.sh` runs them all (as `-A`). Only regress and
features, less the slow ones, are picked this way: perf, visual and kts run by
name or with `-a`. With nothing covered, it says so and runs smoke alone.

Tests run 8 at once (a quarter of the CPUs, 1 to 8; `-j N`). Those tagged
`serial` (`# tags: serial`), whose numbers need the machine otherwise idle
(CPU use, latency, time taken: `resize-spin`, `jump-labels-time`, perf,
visual), run after the others, one at a time.

## How it works

`run.sh` runs each test (`sh tests/CAT/NAME.sh`) under `timeout`, with a run
dir and a unique id (`KM_RUN_ID`, e.g. `km3fa9c1`). The test sources
`lib/h.sh`, which sets up a private world in the run dir:

- `XDG_RUNTIME_DIR`: kak's sockets, kak-lsp's, and a kak-tree-sitter server of
  its own (from `PATH`, so `/usr/bin`); `XDG_CACHE_HOME`, `TMPDIR`,
  `TMUX_TMPDIR`, `GIT_CONFIG_GLOBAL` (branch `trunk`, user `t`) all private.
- `XDG_CONFIG_HOME`: the real `~/.config` symlinked, except `kak` (built from
  the checkout, `~/.config/kak` in it rewritten to point there),
  `kakbr` (the checkout's) and `kak-tree-sitter` (copied). `scripts/` go to a
  private bin dir first on `PATH`. `KM_SRC=DIR` builds from another checkout.
- Sessions are `$PFX-NAME` (`PFX` = the run id); tmux sockets
  `kakmux-$PFX-NAME` (the kakrc tells kakmux by `*/kakmux-*`) or
  `$PFX-tmux-NAME`. The run dir must not contain `kakmux-`.
- Every process started carries `KM_RUN_ID` in its environment. The EXIT trap
  stops each session (`kill!`, then its tmux server and kak-lsp with its
  language servers), the kak-tree-sitter server, then kills whatever process
  still has that `KM_RUN_ID` (never by name: no `pkill`). `run.sh` sweeps the
  same id again after a timeout.

A test passes when it exits 0 and, if `NAME.expected` exists, its output
matches it after `lib/norm.sh` (run dir → `@RUN`, checkout → `@SRC`, `$HOME` →
`~`, the run id → `@P`, PIDs, temp name suffixes, clock times, git hashes,
trailing blanks, long blank runs → `<pad>`). Assertions in the test print
`ok   ...` or `FAIL ...` lines; any `FAIL` fails it. Failed runs keep their
run dir (path printed); `-k` keeps all.

Perf tests print `metric NAME VALUE UNIT` lines (what `perf-diff` compares)
and assert generous ceilings (several times today's numbers, or exact zeros
for idle). Visual tests sample `capture-pane` as fast as it goes and check
with `lib/frames.py`: no sideways shifts, no ● or git flag dropped from an
unchanged line, no vertical reversals.

## Requirements

kak, kak-lsp, kak-tree-sitter with grammars (`ktsctl sync c`), clangd, tmux,
fzf, rg, bat, fd, git, jq, broot, script(1) (util-linux), python3, make and cc
(fixture build check). Tests missing a tool print `SKIP`. shellcheck is used
by `just lint` when installed.

## Adding a test

```sh
# tests/features/thing.sh
# thing: what it checks, in a line or two
# golden                      (optional: compare the output with thing.expected)
# tags: slow                  (optional: left out of just test; serial: run alone)
# covers: rc/thing.kak        (what it tests: the files whose changes run it)
# timeout: 400                (optional, seconds; default 300)
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"                  # C project in git (lib/fixtures.sh)
CWD=$P start kakmux t main.c              # MODE kakmux|tmux|notmux, NAME, kak args
waitdiags t 0                             # until kak-lsp has published
send t 'execute-keys gg'                  # kak commands in client0 (CL=client1 ...)
keys t j                                  # tmux send-keys
expect "cursor" "$(qv t '%val{cursor_line}')" 2
cap t | head -5                           # the screen (golden)
expect "debug" "$(dbge t)" ""             # *debug* less startup noise
```

Then `just update-expected thing` for a golden test, and check the
`.expected` by eye. Helpers (`lib/h.sh`): `start stop send q qv keys term esc cap
dbg dbge attach attachf popwin pcap pkeys pdirs waitdiags waitfor waitout
waitcap waitfile panes fzfready fzfst popen ptype pclose pickerdone sync
idle settle quiet alive
kakpid cputicks expect expectw expect_match expectw_match expect_le expect_ge
fail skip need metric shells shtop myfzf nlines`. `attachf` gives a client
whose terminal input is a fifo (`term NAME '\033[O'` for focus events, keys to
popups); `popwin` makes pickers open in a tmux window (`pcap`/`pkeys`) instead
of a popup.

No fixed sleeps: the helpers that type or send (`send keys term esc pkeys`)
return once kak has handled it and run the idle hooks it set off (`idle`: a
`kak -p` round trip through the client, then another past the 50 ms idle
timeout); `start` once client0 is up and its screen still; `cap`/`pcap` give
the screen once it stops changing (`settle`). What happens later, in the
background (kak-lsp, git, a popup closing, a split's client attaching), the
test waits on by what it checks next: `expectw LABEL WANT CMD...` (expect,
polling CMD until it prints WANT), `waitout`, `waitcap`, `waitdiags`, `panes`;
pickers: `fzfready [QUERY]` (every fzf listens on `$R/o/fzf.sock`: up, its
list read, QUERY searched) and `pickerdone` (the popup gone, what it sent kak
handled); perf tests `quiet` (kak's CPU and shell count still, no `kak -p`
to count), visual ones `settled` (`lib/visual.sh`: kak-lsp's inline
diagnostics for the buffer as it is). A `sleep` left in a test is for time
that has to pass (an idle timer, a debounce, a window something is counted
or sampled over), and says so.

## Known flakes and quirks

- rg's result order and clangd's order of references vary: tests sort those
  lines or pick a query with one match.
- Timing: tests wait on what they check next rather than sleep, so load
  slows them rather than failing them; perf and visual tests (and those
  tagged `serial`) are only meaningful alone.
- `rename-edges`/`rename-failed` wait 20 s for the rename timer (`slow`).
- `palette` fails now and then, mostly under `-j` (a run in several): the
  picker's column relayout can settle narrower (`%val{cl…` cut at 37
  columns rather than 55). That's kak-picker's `--layout`, not the test's
  timing: waiting longer doesn't change it. Rerun it alone.
- `accepting connection failed`, `Error while transfering remote messages`
  in `*debug*`: a `kak -p` race, harmless; `dbge` drops them.
- `<esc>` to kak goes with `esc NAME` (tmux send-keys): a raw `\033` written
  to an `attachf` client's terminal reaches kak as the prefix of the next key
  (`<a-u>` for `\033` then `u`). A raw `\033` is fine for a popup's fzf.
- `;` on a line whose inline diagnostics follow the cursor logs `recursive
  call of hook NormalKey/<semicolon>, not executing` (the kakrc's
  line-diags-follow runs `execute-keys ',;x'` inside that key's hook;
  harmless, `smoke-keys` filters it).
- kak-tree-sitter + stock rc: changing a buffer's filetype logs
  `'remove-highlighter': no such id: 'c'` (`indent-filetype` filters it).
- Kakoune 2026.05.21 was seen to segfault once in a long session
  (`perf/general` round 3, `perf/wedge`); those tests fail with "kak died".
