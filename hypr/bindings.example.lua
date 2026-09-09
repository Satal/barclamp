-- barclamp keybindings. Append to ~/.config/hypr/bindings.lua.
--
-- Omarchy's stock media keys point at omarchy.media. If that plugin is
-- disabled (it is by default) those keys do nothing, so they are unbound
-- before being pointed at cliamp. Drop the four hl.unbind lines if you have
-- omarchy.media enabled and would rather keep its generic MPRIS handling.

hl.unbind("XF86AudioPlay")
hl.unbind("XF86AudioPause")
hl.unbind("XF86AudioNext")
hl.unbind("XF86AudioPrev")

-- Play/pause starts cliamp and begins playing when it is not running, rather
-- than doing nothing.
o.bind("XF86AudioPlay", "Play/pause music", "omarchy-shell cliamp playPause", { locked = true })
o.bind("XF86AudioPause", "Play/pause music", "omarchy-shell cliamp playPause", { locked = true })
o.bind("XF86AudioNext", "Next track", "omarchy-shell cliamp next", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "omarchy-shell cliamp previous", { locked = true })

-- Open the picker to choose a favourite stream or a playlist. Routed through
-- the shell rather than the plugin's own IPC: bar widgets are instantiated once
-- per monitor, and the shell picks the one on the focused screen instead of
-- opening a popup on every display. Omarchy's stock SUPER + SHIFT + ALT + M
-- still opens the full cliamp TUI.
o.bind("SUPER + ALT + M", "Choose music", "omarchy-shell shell toggle io.github.satal.cliamp")
