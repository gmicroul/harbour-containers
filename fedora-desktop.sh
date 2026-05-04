#!/bin/bash
# Fedora desktop launcher for harbour-containers (manual env setup)
# Run on host as defaultuser
# Usage: sh fedora-desktop.sh [portrait|landscape]

ORIENTATION="${1:-portrait}"
CONTAINER="fedora"

# Find next available display ID
LAST_ID=$(ls /run/display/wayland-container-* 2>/dev/null | grep -v lock | sort -t'-' -k3 -n | tail -1 | grep -o '[0-9]*$')
DISPLAY_ID=$((LAST_ID + 1))

echo "[+] Using display ID: $DISPLAY_ID ($ORIENTATION)"

# Setup env
export XDG_RUNTIME_DIR=/run/user/100000
export QT_QPA_PLATFORM=wayland

# Start qxcompositor in background
/usr/bin/qxcompositor --wayland-socket-name "display/wayland-container-$DISPLAY_ID" -o $ORIENTATION &
QXPID=$!

# Wait for socket
for i in 1 2 3 4 5; do
    sleep 1
    if [ -S "/run/display/wayland-container-$DISPLAY_ID" ]; then
        echo "[+] Socket created: wayland-container-$DISPLAY_ID"
        break
    fi
    if [ $i -eq 5 ]; then
        echo "[!] Failed to create display socket"
        kill $QXPID 2>/dev/null
        exit 1
    fi
done

# Start desktop in container
echo "[+] Starting Fedora desktop..."
devel-su lxc-attach -n $CONTAINER -- /opt/bin/start_desktop.sh $DISPLAY_ID user 2>/dev/null &

echo "[+] Fedora desktop running. Keep this terminal open."
echo "[+] Press Ctrl+C to stop."

wait $QXPID