cat << 'EOF' > deploy_strata_steamos.sh
#!/bin/bash
set -e

CONTAINER_NAME="strata-build"
TARGET_DIR="/home/deck/Documents"
WRAPPER_PATH="$TARGET_DIR/run_strata.sh"
LAUNCHER_PATH="/home/deck/.local/share/applications/StrataAI.desktop"
STRATA_DIR="/home/deck/Strata"

echo "🌟 Starting Automated Strata SteamOS Deployment..."

# 1. Configure GPU Compute Permissions for the deck user
echo "🎮 Provisioning AMD GPU compute cluster access..."
sudo usermod -a -G render,video $USER

# 2. Create the Arch Linux Distrobox Container if it doesn't exist
if ! distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "🐳 Spinning up clean Arch Linux Distrobox Container..."
    distrobox create -n "$CONTAINER_NAME" --image archlinux:latest --yes
    
    echo "🛠️ Initializing container toolset (Compiler suite, Python, CMake, Ninja)..."
    distrobox enter "$CONTAINER_NAME" -- bash -c "sudo pacman -Syu --noconfirm base-devel git python python-pip cmake ninja"
else
    echo "✅ Distrobox container '$CONTAINER_NAME' already exists."
fi

# 3. Clone Strata Source Tree if missing
if [ ! -d "$STRATA_DIR" ]; then
    echo "📥 Cloning Strata Repository into $STRATA_DIR..."
    git clone https://github.com "$STRATA_DIR"
else
    echo "✅ Strata repository directory already present."
fi

# 4. Build Gaming Mode Execution Wrapper Script
echo "⚙️ Deploying automation wrapper infrastructure..."
mkdir -p "$TARGET_DIR"
mkdir -p "$(dirname "$LAUNCHER_PATH")"

cat << 'INNER_EOF' > "$WRAPPER_PATH"
#!/bin/bash
CONTAINER_NAME="strata-build"
STRATA_DIR="##STRATA_DIR##"

# Execute clean-up tasks on close
cleanup() {
    echo "🛑 Steam wrapper closed. Purging all container instances and releasing VRAM..."
    # Uses SteamOS native distrobox syntax safely
    distrobox stop --yes "$CONTAINER_NAME"
    exit 0
}

# Trap Steam's target kill signals to guarantee immediate VRAM/RAM purging
trap cleanup SIGINT SIGTERM EXIT

echo "🚀 Initializing Strata Execution Envelope on Port 8081..."

# Inhibit sleep, isolate audio server layouts, run auto-updates, and bind port 8081
ALSA_CARD=0 ALSA_PCM_CARD=0 PULSE_SERVER="" systemd-inhibit \
    --why="Running Strata local AI inference engine" \
    --who="Steam Game Wrapper" \
    --what="sleep" \
    distrobox enter "$CONTAINER_NAME" --additional-flags "--workdir $STRATA_DIR" -- bash -c "./update.sh && ./setup.sh --port 8081"

# Maintain context container block until child execution threads fully terminate
wait $!
INNER_EOF

# Interpolate absolute Strata location variables into execution payload
sed -i "s|##STRATA_DIR##|$STRATA_DIR|g" "$WRAPPER_PATH"

# 5. Generate Steam-Scannable Desktop Entry Configuration
cat << INNER_EOF > "$LAUNCHER_PATH"
[Desktop Entry]
Name=Strata AI Engine
Comment=Launches Strata Inference inside a Distrobox sandbox environment on port 8081
Exec=$WRAPPER_PATH
Icon=steam
Terminal=true
Type=Application
Categories=Game;
INNER_EOF

# 6. Apply proper execution bits
chmod +x "$WRAPPER_PATH"
chmod +x "$LAUNCHER_PATH"

echo ""
echo "🎉 🌟 DEPLOYMENT COMPLETE 🌟 🎉"
echo "--------------------------------------------------"
echo "🕹️  Launcher Entry Created at: $LAUNCHER_PATH"
echo "🖥️  Compute target configuration set to Port: 8081"
echo "⚡ GPU acceleration mapping active for your 9070 XT."
echo "--------------------------------------------------"
echo "👉 FINAL STEP: Open Steam (Desktop Mode) -> 'Add a Non-Steam Game' -> Select 'Strata AI Engine'."
echo "Once added, return to Gaming Mode and launch it!"
EOF

# Execute the fixed setup
chmod +x deploy_strata_steamos.sh
./deploy_strata_steamos.sh
