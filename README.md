# kakmux

A Kakoune config that brings over Helix's good parts (its keys, pickers, status
line, inline diagnostics, tree-sitter, LSP), plus tmux integration: `kakmux`
runs kak in its own tmux server whose status line is the bufferline and whose
panes are kak's splits; `kakbr` puts a broot sidebar beside it.

## Layout

| Path | What it is | Deployed as |
| --- | --- | --- |
| `kakrc` | The config: a port of Helix's `config.toml`/`languages.toml`, safe to `:config-reload` | `~/.config/kak/kakrc` |
| `colors/onedark.kak` | Colour scheme | `~/.config/kak/colors/` |
| `bin/kak-picker` | fzf pickers in a tmux popup (files, buffers, grep, symbols, diagnostics, palette) | `~/.config/kak/bin/` |
| `bin/kakmux-even` | Evens out kakmux's splits | `~/.config/kak/bin/` |
| `kakmux.conf` | tmux config of a kakmux server | `~/.config/kak/kakmux.conf` |
| `kakbr/` | tmux config of a kakbr server, broot config of its sidebar | `~/.config/kakbr/` |
| `scripts/kakmux` | kak in its own tmux server (`kakmux-PID`) | `~/.local/bin/kakmux` |
| `scripts/kakbr-sidebar` | kakbr's left pane: broot at the sidebar's width | `~/.local/bin/kakbr-sidebar` |
| `scripts/broot-open` | broot's Enter and double-click open files in kak | `~/.local/bin/broot-open`, `~/.local/lib/broot-opener/{xdg-open,wslview}` |
| `shell/kakmux.zsh` | `kak()` (picks up `:kakmux`'s handoff), `kakbr()`, `broot()` (opener on PATH) | sourced by `~/.zshrc` |
| `tests/` | Test suite (`just test`, `just lint`, `just perf`); see `tests/README.md` | not deployed |

The kakrc and scripts call each other by those deployed paths
(`~/.config/kak/bin/...`, `~/.config/kak/kakmux.conf`), so they need to be
there; the tests build a private copy with the paths pointed at it.

## Deployment

It can live in a dotfiles repo as a git submodule, with each file above
symlinked into place by whatever deploys the dotfiles (so editing the
submodule's checkout edits the live config).

Standalone:

```sh
git clone https://github.com/sochinorth/kakmux.git ~/kakmux
ln -s ~/kakmux ~/.config/kak                     # kakrc, colors/, bin/, kakmux.conf in place
ln -s ~/kakmux/kakbr ~/.config/kakbr
mkdir -p ~/.local/bin ~/.local/lib/broot-opener
for f in kakmux kakbr-sidebar broot-open; do ln -s ~/kakmux/scripts/$f ~/.local/bin/; done
for f in xdg-open wslview; do ln -s ~/kakmux/scripts/broot-open ~/.local/lib/broot-opener/$f; done
echo 'source ~/kakmux/shell/kakmux.zsh' >> ~/.zshrc
```

## Requirements

kakoune, kakoune-lsp (and the language servers: clangd, ...), kak-tree-sitter
with grammars (`ktsctl sync <lang>`), tmux, fzf, fd, ripgrep, bat, git, broot.
The kakrc rewrites `~/.config/kak-tree-sitter/config.toml` whenever the set of
installed grammars changes, to hand languages without one back to Kakoune's
highlighter.

Known upstream issues (not this config's): kak-tree-sitter 3.2.2 has three
server bugs (duplicate answers, column-0 node ends, sessions stuck as tracked),
fixed in a patched build, 3.2.2-3 (`tests/kts` checks for them); with it, its
rc removes Kakoune's `window/<lang>` highlighter itself, so the stock c-family
hook's own removal logs an error in `*debug*` when a buffer's filetype changes.
