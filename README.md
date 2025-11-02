# volumio-community-pi4-dual-hdmi-touch-guide

Configuration and scripts for running Volumio on Raspberry Pi 4 with separate HDMI video/audio outputs and touchscreen support.

\# Volumio Pi 4 – Dual HDMI (Touchscreen Video + Soundbar Audio)

**Version:** Playbook v2.1 (self-tested)  

**Author:**   
\[@redeyeninja\](<https://community.volumio.com/u/redeyeninja>)  
\[@RedEyeNinja-BKK\](<https://github.com/RedEyeNinja-BKK>)

**Platform:** Raspberry Pi 4 B (8 GB) · Volumio 4 (Bookworm) · LCDWIKI 8" 1280×800 Touch Display · Samsung Soundbar (HDMI-1)

\---

\## ⚠️ Disclaimer

This repository documents an **experimental community workaround**, not an official Volumio feature.  

It changes how the display stack `xrandr`, `xinput`, `systemd`) interacts with Volumio’s **kiosk** and **Touch Display** plugin.  

Use it for learning or experimentation — **not in production** — and expect future Volumio updates to override or break these changes.

For official display management, refer to the  

👉 \[Volumio Touch Display Plugin v3.5.6 (Bookworm)\](<https://github.com/volumio/volumio-plugins-sources-bookworm/tree/master/touch_display>)

\---

\## 🧭 Goal

Provide a **pixel-perfect UI** on the HDMI-0 touch LCD (1280×800)  

while routing **audio-only** to HDMI-1 (e.g., a soundbar).

\### ✅ Result

| Component | Port | Function | Status |

|------------|------|-----------|---------|

| LCDWIKI 8" 1280×800 Touchscreen | HDMI-0 `HDMI-1` in KMS) | Video + Touch UI | ✓ Native 1280×800 |

| Samsung Soundbar | HDMI-1 `HDMI-2` in KMS) | Audio only | ✓ PCM / Bitstream |

| Volumio UI / Touch Display Plugin | — | Full UI Control | ✓ Stable |

| PeppyMeter Basic | — | VU Meter Display | ✓ Renders on LCD |

\---

\## 🧰 Hardware

\- Raspberry Pi 4B (8 GB)  

\- LCDWIKI 8" 1280×800 HDMI touchscreen  

\- POE HAT + Power Filter HAT + Generic HiFiBerry Digi HAT  

\- Samsung Soundbar (HDMI ARC)  

\- Powered via 5 V USB charger (\~3 A recommended)

\---

# ## 🪜 Setup Guide

\### 0️⃣ Preparation

1\. Flash Volumio 4 (Bookworm) to microSD / USB.

2\. Connect:

   - LCD → **HDMI-0 + USB**

   - Soundbar → **HDMI-1**

3\. In Volumio Plugins → Install and enable:

   - **Touch Display**

   - **Now Playing** (optional)

4\. In **Playback Options** → Output Device = `HDMI 1`.

\---

volumio-community-pi4-dual-hdmi-touch-guide/
├── LICENSE
├── README.md  
├── usr/
│   └── local/
│       └── bin/
│           └── [fix-outputs.sh](http://fix-outputs.sh)
├── etc/
│   ├── X11/
│   │   └── xorg.conf.d/
│   │       └── 10-monitor.conf
│   └── systemd/
│       └── system/
│           ├── outputs-fix.service
│           ├── outputs-fix.service.d/
│           │   └── override.conf
│           └── peppymeterbasic.service.d/
│               ├── override.conf
│               └── 10-groups.conf

---

## Playbook v2.1

**Pi 4: HDMI-0 video (touch LCD @1280×800) + HDMI-1 audio (soundbar), with reliable touch**  
 Tested on: Raspberry Pi 4B (8 GB), Volumio (Bookworm), LCDWIKI 8" 1280×800 HDMI touch, Samsung soundbar on HDMI-1.  
 **Goal:** Pixel-perfect UI on the 1280×800 LCD via HDMI-0, audio out via HDMI-1 — no stretching. Touch works reliably.

### 0) Prep & install

- Flash Volumio, boot. Connect:
  - LCD (video + its USB touch) → **HDMI-0** / USB
  - Soundbar → **HDMI-1**
- In *Plugins* install and enable:
  - **Touch Display**
  - **Now Playing** (optional; works with this setup)
- In *Playback Options* set **Output device = HDMI 1** (the soundbar).

### 1) Pi firmware boot config

Edit `/boot/userconfig.txt`:

```
# --- Pi4 + KMS base ---
dtoverlay=vc4-kms-v3d-pi4,audio=on
disable_overscan=1
hdmi_blanking=0

# --- Force HDMI0 (left, X=HDMI-1) video-only at boot ---
hdmi_force_hotplug:0=1
hdmi_ignore_edid_audio:0=1
hdmi_drive:0=1

# --- Force HDMI1 (right, X=HDMI-2) to expose audio at boot ---
hdmi_force_hotplug:1=1
hdmi_force_edid_audio:1=1

# --- Light OC for smoother UI (optional) ---
gpu_freq=650
over_voltage=4
force_turbo=0

# --- Optional/legacy on Pi4; harmless if present ---
# config_hdmi_boost=7
# max_usb_current=1

# --- Optional: disable unused buses ---
dtparam=spi=off
dtparam=uart=off
```

Reboot.

### 2) (Optional) Pin HDMI-0 to 1280×800 via Xorg

Create `/etc/X11/xorg.conf.d/10-monitor.conf`:

```
Section "Monitor"
    Identifier "HDMI-1"
    Option "PreferredMode" "1280x800"
EndSection

Section "Screen"
    Identifier "Screen0"
    Monitor "HDMI-1"
EndSection
```

> Note: With KMS, **physical HDMI-0** appears as `HDMI-1` in X; HDMI-1 appears as `HDMI-2`.

### 3) Tools used by the helper

```
sudo apt-get update
sudo apt-get install -y xinput x11-xserver-utils
```

### 4) Layout + touch-mapping helper

`/usr/local/bin/fix-outputs.sh`:

```
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
```

Make it executable:

```
sudo chmod +x /usr/local/bin/fix-outputs.sh
```

### 5) One-shot systemd unit

`/etc/systemd/system/outputs-fix.service`:

```
[Unit]
Description=Fix display layout and touch mapping for Volumio kiosk
After=volumio-kiosk.service now_playing.service
Wants=volumio-kiosk.service now_playing.service

[Service]
Type=oneshot
User=volumio
Group=volumio
Environment=DISPLAY=:0
Environment=XAUTHORITY=/var/lib/volumio/.Xauthority
ExecStartPre=/bin/sleep 3
ExecStart=/usr/local/bin/fix-outputs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Ensure a sane PATH for oneshot services:

```
sudo install -d -m 0755 /etc/systemd/system/outputs-fix.service.d
printf "[Service]\nEnvironment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n" \
 | sudo tee /etc/systemd/system/outputs-fix.service.d/override.conf >/dev/null
```

Enable & start:

```
sudo systemctl daemon-reload
sudo systemctl enable outputs-fix.service
sudo systemctl start outputs-fix.service
```

You should see on first run:

```
[fix-outputs] Touch mapped to HDMI-1 (name: QDtech MPI1001)
```

### 6) Verify

```
DISPLAY=:0 xrandr
# Expect:
# HDMI-1 connected primary 1280x800+0+0
# HDMI-2 connected 1920x1080+1280+0

DISPLAY=:0 XAUTHORITY=/var/lib/volumio/.Xauthority xinput list | grep -E 'QDtech|MPI|Touch'
DISPLAY=:0 XAUTHORITY=/var/lib/volumio/.Xauthority \
  xinput list-props "QDtech MPI1001" | egrep -i 'Coordinate Transformation Matrix|Calibration'
# Expect a non-identity CTM (e.g. 0.400000 ... 0.740741 ...)
```

If you adjust *Touch Display* → UI scale, reboot once to apply.

### 7) Notes & gotchas

- **Power:** Touch LCDs powered from the Pi can be marginal (especially with HATs/Wi-Fi). If touch is flaky or heavy touches crash UI, power the LCD from a stable 5 V supply.
- **Now Playing:** Works; we order after the kiosk (and optionally after now_playing).
- **Cold-boot race:** If mapping ever misses on cold boots, increase `ExecStartPre=/bin/sleep 3` to `sleep 5` and/or restart:

  ```
  sudo systemctl restart outputs-fix.service
  ```

### 8) Manual recovery one-liners

```
# Remap touch interactively (no reboot)
DISPLAY=:0 XAUTHORITY=/var/lib/volumio/.Xauthority xinput map-to-output "QDtech MPI1001" HDMI-1

# Re-run the fix and see logs
sudo systemctl restart outputs-fix.service
journalctl -u outputs-fix.service --no-pager | tail -n 50
```

### 9) PeppyMeter Basic on the left head (HDMI-1 @ 0,0)

Create a drop-in:

```
sudo mkdir -p /etc/systemd/system/peppymeterbasic.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/peppymeterbasic.service.d/override.conf >/dev/null
[Unit]
Wants=outputs-fix.service
After=outputs-fix.service

[Service]
Environment=DISPLAY=:0
Environment=XAUTHORITY=/var/lib/volumio/.Xauthority
Environment=SDL_VIDEO_FULLSCREEN_DISPLAY=0
Environment=SDL_VIDEO_WINDOW_POS=0,0
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF

sudo systemctl daemon-reload
sudo systemctl restart peppymeterbasic.service
```

Then start a track; the VU meters should pop up on the touchscreen.

### 10) Optional post-setup enhancements (recommended)

**GPU access for** `volumio`**:**

```
sudo usermod -aG render,video volumio
sudo mkdir -p /etc/systemd/system/peppymeterbasic.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/peppymeterbasic.service.d/10-groups.conf >/dev/null
[Service]
SupplementaryGroups=render video
EOF
sudo systemctl daemon-reload
```

**Fix Mesa shader cache (choose one):**

- **A)** keep it in home (simple):

  ```
  sudo chown -R volumio:volumio /home/volumio/.cache
  ```
- **B)** move to tmp (nice on read-only images):

  ```
  # add to the same peppymeter drop-in:
  Environment=MESA_SHADER_CACHE_DIR=/tmp/mesa_shader_cache
  ```

These remove GPU “permission denied” errors and ensure PeppyMeter uses hardware accel cleanly.

### 11) What “good” looks like

- `journalctl -u outputs-fix.service` shows **one** “Touch mapped to HDMI-1 (name: QDtech MPI1001)” per boot/restart.
- `xrandr` shows a 3200×1080 desktop with:
  - `HDMI-1 1280x800+0+0 primary` (LCD)
  - `HDMI-2 1920x1080+1280+0` (soundbar)

**Final layout on disk**

```
/usr/local/bin/fix-outputs.sh
/etc/X11/xorg.conf.d/10-monitor.conf              # (optional pin)
/etc/systemd/system/outputs-fix.service
/etc/systemd/system/outputs-fix.service.d/override.conf
/etc/systemd/system/peppymeterbasic.service.d/override.conf
# (+ optional peppymeterbasic 10-groups.conf)
```