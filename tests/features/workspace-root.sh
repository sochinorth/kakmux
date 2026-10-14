# workspace-root: per buffer, the nearest .git/.helix dir above it, else
# kak's cwd (scratch and *debug* buffers: kak's cwd's)
# golden
# covers: rc/workspace.kak
. "$(dirname "$0")/../lib/h.sh"
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub/deep" "$P/hx/.helix" "$R/p/nows"; echo x > "$P/sub/deep/a.txt"; echo y > "$P/hx/b.txt"; echo z > "$R/p/nows/c.txt"
CWD=$P/sub WAIT=2 start tmux w deep/a.txt
expect "in a repo: its root" "$(qv w '%opt{workspace_root}')" "$P"
send w "edit $P/hx/b.txt"; expect ".helix dir" "$(qv w '%opt{workspace_root}')" "$P/hx"
send w "edit $R/p/nows/c.txt"; expect "outside: kak's cwd" "$(qv w '%opt{workspace_root}')" "$P/sub"
send w "edit -scratch *s*"; q w '%opt{workspace_root}'
send w "buffer *debug*"; q w '%opt{workspace_root}'
dbge w | tail -5
