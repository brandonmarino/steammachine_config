#!/bin/bash

SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

echo "=== 1. CREATING MONITORING DAEMON ==="
cat << 'EOF' > "$HOME/keepawake_daemon.sh"
#!/bin/bash

# 1 hour buffer in seconds
BUFFER_TIME=3600
TIME_REMAINING=0
INHIBIT_PID=""

clean_up() {
    echo "Stopping Keepawake Daemon..."
    if [ -n "$INHIBIT_PID" ]; then
        kill "$INHIBIT_PID" 2>/dev/null
    fi
    exit 0
}
trap clean_up SIGTERM SIGINT

echo "Strata Keepawake Monitoring Daemon Started."

while true; do
    # Check 1: Count active, established SSH connections
    SSH_COUNT=$(ss -t -a state established '( dport = :ssh or sport = :ssh )' | wc -l)
    # ss output includes a header row, subtract 1 if greater than 0
    if [ "$SSH_COUNT" -gt 0 ]; then SSH_COUNT=$((SSH_COUNT - 1)); fi

    # Check 2: Check if Ollama is actively processing or running a model
    OLLAMA_ACTIVE=0
    if pgrep -x "ollama" > /dev/null; then
        # If ollama runner processes are consuming CPU or memory context, consider active
        if pgrep -f "ollama runner" > /dev/null || pgrep -f "ollama_llama_server" > /dev/null; then
            OLLAMA_ACTIVE=1
        fi
    fi

    # Evaluation logic
    if [ "$SSH_COUNT" -gt 0 ] || [ "$OLLAMA_ACTIVE" -eq 1 ]; then
        # Reset the buffer to full 1 hour if actively working
        if [ "$TIME_REMAINING" -lt "$BUFFER_TIME" ]; then
            echo "[$(date)] Active session detected (SSH: $SSH_COUNT, Ollama: $OLLAMA_ACTIVE). Resetting buffer to 1 hour."
        fi
        TIME_REMAINING=$BUFFER_TIME
    else
        # Count down if idle
        if [ "$TIME_REMAINING" -gt 0 ]; then
            TIME_REMAINING=$((TIME_REMAINING - 60))
            if [ "$TIME_REMAINING" -le 0 ]; then
                echo "[$(date)] Buffer expired. Releasing system sleep locks."
                TIME_REMAINING=0
            fi
        fi
    fi

    # Handle the systemd sleep inhibitor lock
    if [ "$TIME_REMAINING" -gt 0 ]; then
        if [ -z "$INHIBIT_PID" ] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
            # Spawn a persistent system block that blocks sleep/idle timeouts
            systemd-inhibit --what=sleep:idle --who="Keepawake Daemon" --why="SSH/Ollama session active or buffered" sleep 86400 &
            INHIBIT_PID=$!
        fi
    else
        if [ -n "$INHIBIT_PID" ]; then
            kill "$INHIBIT_PID" 2>/dev/null
            INHIBIT_PID=""
        fi
    fi

    sleep 60
done
EOF
chmod +x "$HOME/keepawake_daemon.sh"

echo "=== 2. CREATING SYSTEMD USER SERVICE ==="
cat << EOF > "$SYSTEMD_DIR/steam-keepawake.service"
[Unit]
Description=Keep Steam Machine Awake During SSH or Ollama Activity
After=network.target

[Service]
Type=simple
ExecStart=$HOME/keepawake_daemon.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "=== 3. STARTING AND ENABLING SERVICE ==="
systemctl --user daemon-reload
systemctl --user enable steam-keepawake.service
systemctl --user start steam-keepawake.service

echo "=== KEEP-AWAKE MONITORING DEPLOYED ==="
echo "Your Steam Machine will now stay awake while coding, and remain awake for exactly 1 hour after you disconnect."
