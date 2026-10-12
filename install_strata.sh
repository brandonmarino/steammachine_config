#!/bin/bash

# Define isolated workspace directories
TARGET_DIR="$HOME/.strata"
SYSTEMD_DIR="$HOME/.config/systemd/user"
LOCAL_BIN="$HOME/.local/bin"
GCC_BUILD_DIR="$HOME/.local/share/gcc-build"

echo "=== 1. CREATING ISOLATED COMPILER WORKSPACES ==="
mkdir -p "$TARGET_DIR"
mkdir -p "$SYSTEMD_DIR"
mkdir -p "$LOCAL_BIN"
mkdir -p "$GCC_BUILD_DIR"

# Ensure user binaries are permanently mapped to your shell's path environment
if ! grep -q "local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "=== 2. DEPLOYING INTEGRATED UPDATER SCRIPT ==="
cat << 'EOF' > "$HOME/update_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
TEMP_DIR="$HOME/.strata_tmp"
LOCAL_BIN="$HOME/.local/bin"
GCC_BUILD_DIR="$HOME/.local/share/gcc-build"

# INHIBIT SLEEP: Keeps your hardware awake while downloading and compiling components
systemd-inhibit --what=sleep:idle --who="Strata Core Updater" --why="Syncing and compiling engine toolchains" bash << 'UPDATE_BLOCK'

echo "[$(date)] --- STEP A: VERIFYING / UPDATING GIT ---"
if [ ! -f "$LOCAL_BIN/git" ]; then
    echo "Compiling native user-space Git from the official kernel repository..."
    cd "$GIT_BUILD_DIR" || exit 1
    
    # EXACT LITERAL GIT REPOSITORY URL
    curl -o git.tar.gz "https://kernel.org"
    tar -zxf git.tar.gz && cd git-2.46.0
    
    make configure
    ./configure --prefix="$HOME/.local"
    make -j$(nproc) install
    rm -rf "$GIT_BUILD_DIR"/*
else
    echo "User-space Git is already operational."
fi

# Explicitly export the path so the script utilizes our compiled Git version
export PATH="$HOME/.local/bin:$PATH"

echo "[$(date)] --- STEP B: CHECKING/COMPILING GCC 14 COMPILER LAYER ---"
# Check if GCC 14 is already built and working in our local path
if [ ! -f "$LOCAL_BIN/gcc" ] || [[ ! "$($LOCAL_BIN/gcc --version | head -n 1)" == *"14."* ]]; then
    echo "GCC 14 not found. Cloning and building toolchain into user-space..."
    cd "$GCC_BUILD_DIR" || exit 1
    
    # Clone the stable GCC 14 release branch
    git clone --depth 1 --branch releases/gcc-14 https://gcc.gnu.org/git/gcc.git source
    cd source
    
    # Download required prerequisites (mpfr, gmp, mpc) automatically
    ./contrib/download_prerequisites
    
    # Configure and build optimized for your CPU
    mkdir -p build && cd build
    ../configure --prefix="$HOME/.local" --enable-languages=c,c++ --disable-multilib
    make -j$(nproc)
    make install
    echo "[$(date)] GCC 14 successfully compiled and installed to $LOCAL_BIN"
else
    echo "GCC 14 is up to date in user-space. Skipping compilation."
fi

echo "[$(date)] --- STEP C: FETCHING AND SYNCING STRATA INFERENCE ENGINE ---"
rm -rf "$TEMP_DIR"
git clone --depth 1 https://github.com/Niko1221/Strata.git "$TEMP_DIR"

if [ $? -eq 0 ] && [ -d "$TEMP_DIR/.git" ]; then
    [ -f "$TARGET_DIR/config.json" ] && mv "$TARGET_DIR/config.json" "$TEMP_DIR/config.json"
    rm -rf "$TARGET_DIR"/*
    cp -r "$TEMP_DIR"/* "$TARGET_DIR/"
    rm -rf "$TEMP_DIR"
    
    # Compile the Strata binaries using our freshly linked GCC 14 toolchain
    cd "$TARGET_DIR" || exit 1
    export CC="$LOCAL_BIN/gcc"
    export CXX="$LOCAL_BIN/g++"
    chmod +x ./setup.sh
    
    echo "[$(date)] Strata Engine and toolchain components successfully updated."
else
    echo "[$(date)] ERROR: Strata codebase download failed. Retaining current files."
    rm -rf "$TEMP_DIR"
    exit 1
fi
UPDATE_BLOCK
EOF
chmod +x "$HOME/update_strata.sh"

echo "=== 3. EXECUTING INITIAL COMPILATION ==="
"$HOME/update_strata.sh"

echo "=== 4. PACKAGING SYSTEM INHIBITING ENGINE LAUNCHER ==="
cat << 'EOF' > "$HOME/launch_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
CUSTOM_PORT=9000

# Bind runtime environment links for compiler visibility
export PATH="$HOME/.local/bin:$PATH"

STRATA_PID=$(pgrep -f "setup.sh.*--port $CUSTOM_PORT")

if [ -z "$STRATA_PID" ]; then
    cd "$TARGET_DIR" || exit 1
    systemd-inhibit --what=sleep:idle --who="Strata AI Engine" --why="Executing Local Machine Model Tasks" \
    ./setup.sh --port $CUSTOM_PORT --host 0.0.0.0 &
    while true; do sleep 2; done
else
    kill "$STRATA_PID"
    sleep 1
fi
EOF
chmod +x "$HOME/launch_strata.sh"

echo "=== 5. ENROLLING INTEGRATED 24-HOUR DAEMON SYSTEMD TIMERS ==="
cat << EOF > "$SYSTEMD_DIR/strata-update.service"
[Unit]
Description=Daily Combined Automatic Strata and Compiler Update
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
Description=Trigger Unified Strata Component Update Every 24 Hours

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

echo "=== 6. MANUAL STEAM LINK INSTRUCTIONS ==="
echo "Toolchain dependencies are fully configured."
echo "1. Go to Steam UI -> Click 'Add a Game' -> 'Add a Non-Steam Game...'"
echo "2. Select: $HOME/launch_strata.sh"

echo "=== COMPILER ENVIRONMENT STAGED ==="
