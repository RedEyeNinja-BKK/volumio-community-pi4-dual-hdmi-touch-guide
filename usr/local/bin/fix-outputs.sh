#!/usr/bin/env bash
# Robustly set display layout + touch mapping for Volumio Touch Display (Pi4 + KMS)

set -euo pipefail
export DISPLAY=:0
export XAUTHORITY=/var/lib/volumio/.Xauthority

log(){ echo "[fix-outputs] $*" | systemd-cat -t fix-outputs -p info; }

# Wait for X
for i in {1..30}; do xrandr >/dev/null 2>&1 && break || sleep 1; done

xr="$(xrandr)"
echo "$xr" | grep -q "^HDMI-1 connected" || { log "HDMI-1 not connected"; exit 0; }
echo "$xr" | grep -q "^HDMI-2 connected" || log "HDMI-2 not connected (ok if soundbar off)"

# 1) LCD as primary @1280x800 on the left
xrandr --output HDMI-1 --mode 1280x800 --pos 0x0 --primary --rate 60 --dpi 120

# 2) Soundbar to the right in 1080p60 if available, else its preferred mode
if echo "$xr" | sed -n '/^HDMI-2 connected/,/^\S/p' | grep -q "1920x1080"; then
  xrandr --output HDMI-2 --mode 1920x1080 --pos 1280x0 --rate 60
else
  pref="$(echo "$xr" | awk '/^HDMI-2 connected/{f=1;next}/^\S/{f=0}f&&/\*/{print $1; exit}')"
  [ -n "${pref:-}" ] && xrandr --output HDMI-2 --mode "$pref" --pos 1280x0
fi

# 3) Prevent display blanking (ignore errors)
xset -dpms  || true
xset s off  || true
xset s noblank || true

# 4) Give kiosk/plugins a moment to finish GPU init
sleep 8

# 5) Map touch by NAME with retries (stable)
if command -v xinput >/dev/null 2>&1; then
  name="$(xinput list --name-only | grep -E '^QDtech MPI1001$' | head -n1)"
  [ -z "$name" ] && name="$(xinput list --name-only | grep -E 'QDtech|MPI|Touch|touch|HID' | head -n1)"
  if [ -n "$name" ]; then
    log "Touch candidate: $name"
    for i in $(seq 1 10); do
      xinput map-to-output "$name" HDMI-1 2>/dev/null && { log "Touch mapped to HDMI-1 (name: $name)"; break; }
      sleep 1
    done
    xinput list --name-only | grep -E 'QDtech|MPI|Touch|touch|HID' \
      | while read -r dev; do xinput map-to-output "$dev" HDMI-1 2>/dev/null || true; done
  else
    log "No touch device name found"
  fi
else
  log "xinput not installed; skipping mapping"
fi
