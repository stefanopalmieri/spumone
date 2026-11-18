#!/usr/bin/env bash
# i3 keybinding cheat sheet — shows in rofi

cat <<'EOF' | rofi -dmenu -i -p "i3 Keybindings" -theme spacemacs -theme-str 'window {width: 600px;}'

─── FOCUS ──────────────────────────────
  Mod+h / j / k / l .......... focus left / down / up / right
  Mod+Arrow keys .............. same as above

─── MOVE ───────────────────────────────
  Mod+Shift+h / j / k / l .... move window left / down / up / right
  Mod+Shift+Arrow keys ........ same as above

─── WORKSPACES ─────────────────────────
  Mod+1 - 0 ................... switch to workspace 1-10
  Mod+Shift+1 - 0 ............. move window to workspace 1-10
  Mod+Tab ..................... next workspace
  Mod+Shift+Tab .............. previous workspace
  Mod+Ctrl+h / l ............. move workspace to monitor left / right

─── LAYOUT ─────────────────────────────
  Mod+f ....................... fullscreen toggle
  Mod+v ....................... split toggle (horizontal / vertical)
  Mod+s ....................... stacking layout
  Mod+w ....................... tabbed layout
  Mod+e ....................... split layout

─── WINDOWS ─────────────────────────────
  Mod+q ....................... kill window
  Mod+Shift+space ............ floating toggle
  Mod+space ................... focus floating / tiling toggle
  Mod+Shift+t ................. sticky toggle (follow across workspaces)

─── RESIZE ─────────────────────────────
  Mod+r ....................... enter resize mode, then h/j/k/l
  Mod+a ....................... focus parent container
  Mod+c ....................... focus child container

─── GAPS & BORDERS ─────────────────────
  (configured in i3 config: zero gaps everywhere)

─── APPS ───────────────────────────────
  Mod+Return .................. terminal — emacs vterm
  Mod+d ....................... app launcher (rofi)
  Mod+period .................. emoji picker (rofi-emoji)
  Mod+b ....................... chromium
  Mod+m ....................... emacs
  Mod+n ....................... file manager (pcmanfm)

─── SCRATCHPAD ─────────────────────────
  Mod+Shift+e ................. emacs scratchpad (floating, workspace 10)

─── SYSTEM ─────────────────────────────
  Mod+Escape .................. lock screen
  Mod+Shift+c ................. reload i3 config
  Mod+Shift+r ................. restart i3
  Mod+Shift+x ................. power menu (shutdown / reboot / suspend)
  Mod+x ....................... display / monitor config (arandr)
─── SCREENSHOT ────────────────────────
  PrtSc ....................... full screen → ~/Pictures/Screenshots
  Mod+p ....................... draw region → ~/Pictures/Screenshots
  Mod+Shift+p ................. full screen → ~/Pictures/Screenshots
  Mod+Shift+s ................. draw region → clipboard

  Mod+Shift+? ................. this cheat sheet

─── MEDIA ──────────────────────────────
  XF86Audio* .................. volume up / down / mute
  XF86MonBrightness* .......... brightness up / down
  playerctl ................... play / pause / next / prev

EOF
