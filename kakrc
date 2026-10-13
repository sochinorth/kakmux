# Port of Helix's config.toml and languages.toml. Lines that don't carry over
# are kept as comments saying why.

# Sourcing this again in a running session (:config-reload, Helix's, at the
# end) redoes it all with no errors and nothing twice: commands are
# redefined (-override), highlighters replaced (-override, so they keep
# their place), user modes made once, and every hook is in a kakrc group,
# all of them removed first (rc/base.kak) before they're added again. Options
# keep their values (the state in rc/: diagnostics, gutter flags, bufferline
# caches) unless declared with one, which only settings are. The plugins load
# once: kakrc_loaded, set at the end.

# The config is in rc/ beside this file (%val{config}/rc: ~/.config/kak/rc),
# sourced in this order: each part may use, as it loads, what the ones
# before it define (rc/base.kak has what they all share). Not autoload/: a
# user autoload dir turns off the system one, and loads alphabetically.
source "%val{config}/rc/base.kak"
source "%val{config}/rc/editor.kak"
source "%val{config}/rc/lsp.kak"
source "%val{config}/rc/inline-diagnostics.kak"
source "%val{config}/rc/workspace.kak"
source "%val{config}/rc/keys.kak"
source "%val{config}/rc/editing.kak"
source "%val{config}/rc/decorations.kak"
source "%val{config}/rc/commands.kak"
source "%val{config}/rc/bufferline.kak"
source "%val{config}/rc/pickers.kak"
source "%val{config}/rc/splits.kak"
source "%val{config}/rc/languages.kak"

# Helix's :theme (see rc/commands.kak)
alias global theme picker-colorscheme

# Helix's :config-reload: this file again, in the running session (see the
# top). What it set per window or buffer as they were shown or typed in
# (tab widths, say) stays until they next are.
define-command -override config-reload -docstring 'config-reload: source the kakrc again' %{
	source "%val{config}/kakrc"
	echo -markup '{Information}config reloaded'
}

set-option global kakrc_loaded true
