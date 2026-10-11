#!/bin/bash

TARGET_DIR="$HOME/.strata"
SYSTEMD_DIR="$HOME/.config/systemd/user"
STEAM_CONFIG_DIR=$(find "$HOME/.local/share/Steam/userdata" -maxdepth 2 -name "shortcuts.vdf" 2>/dev/null | head -n 1)

echo "=== 1. CREATING DIRECTORIES ==="
mkdir -p "$TARGET_DIR"
mkdir -p "$SYSTEMD_DIR"

echo "=== 2. CREATING UPDATER SCRIPT ==="
cat << 'EOF' > "$HOME/update_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
TEMP_DIR="$HOME/.strata_tmp"

rm -rf "$TEMP_DIR"

# INHIBIT SLEEP: Blocks power saving states strictly during the git cloning/updating window
systemd-inhibit --what=sleep:idle --who="Strata Updater" --why="Downloading Strata Engine Updates" \
git clone --depth 1 https://github.com "$TEMP_DIR"

if [ $? -eq 0 ] && [ -d "$TEMP_DIR/.git" ]; then
    [ -f "$TARGET_DIR/config.json" ] && mv "$TARGET_DIR/config.json" "$TEMP_DIR/config.json"
    rm -rf "$TARGET_DIR"/*
    cp -r "$TEMP_DIR"/* "$TARGET_DIR/"
    rm -rf "$TEMP_DIR"
    chmod +x "$TARGET_DIR/setup.sh"
    echo "[$(date)] Strata updated successfully."
else
    echo "[$(date)] ERROR: Download failed. Keeping old files."
    rm -rf "$TEMP_DIR"
    exit 1
fi
EOF
chmod +x "$HOME/update_strata.sh"

echo "=== 3. RUNNING INITIAL DOWNLOAD ==="
"$HOME/update_strata.sh"

echo "=== 4. CREATING LAUNCHER SCRIPT ==="
cat << 'EOF' > "$HOME/launch_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
CUSTOM_PORT=9000

STRATA_PID=$(pgrep -f "setup.sh.*--port $CUSTOM_PORT")

if [ -z "$STRATA_PID" ]; then
    cd "$TARGET_DIR" || exit 1
    
    # INHIBIT SLEEP: Forces the system to stay fully awake while your AI model inference server is active
    systemd-inhibit --what=sleep:idle --who="Strata AI Engine" --why="Running Local Inference Model Server" \
    ./setup.sh --port $CUSTOM_PORT --host 0.0.0.0 &
    
    while true; do sleep 2; done
else
    kill "$STRATA_PID"
    sleep 1
fi
EOF
chmod +x "$HOME/launch_strata.sh"

echo "=== 5. SETTING UP DAILY BACKGROUND TIMER ==="
cat << EOF > "$SYSTEMD_DIR/strata-update.service"
[Unit]
Description=Daily Automatic Strata Core Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/update_strata.sh
StandardOutput=append:$HOME/.strata_update.log
StandardError=append:$HOME/.strata_update.log

[Install]
WantedBy=default.target
EOF

cat << EOF > "$SYSTEMD_DIR/strata-update.timer"
[Unit]
Description=Trigger Strata Update Every 24 Hours

[Timer]
OnUnitActiveSec=24h
OnBootSec=15min
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable strata-update.timer
systemctl --user start strata-update.timer

echo "=== 6. ADDING TO STEAM SHORTCUTS ==="
echo "To safely register Strata in your library without corrupting shortcuts.vdf:"
echo "1. Launch your Steam client UI."
echo "2. Select 'Add a Game' (bottom-left) -> 'Add a Non-Steam Game...'"
echo "3. Use the file explorer to open: $HOME/launch_strata.sh"
echo "4. Change its title to 'Strata AI Engine' under its entry properties."

echo "=== INSTALLATION COMPLETE ==="
