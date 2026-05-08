#!/bin/bash
# sailfish-containers-dbus : new qxcompositor display

if [ "$#" -ne 3 ]; then
    echo "Usage $0 [display-id] [user_uid] [screen_orientation]"
    exit 0
fi

DISPLAY_ID=$1
USER_UID=$2
SCREEN_ORIENTATION=$3

# Clean any stale lockfiles for this display
rm -f /run/display/wayland-container-$DISPLAY_ID.lock

# Ensure /run/display directory exists and is writable
if [ ! -d "/run/display" ]; then
    mkdir -p /run/display
    chown $USER_UID:privileged /run/display
fi

export EGL_PLATFORM="wayland"
export QT_QPA_PLATFORM="wayland"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
export PATH="/sbin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/defaultuser/bin"
export PWD="/run/user/$USER_UID"
export QMLSCENE_DEVICE="customcontext"
export XDG_RUNTIME_DIR=/run/user/$USER_UID
export WAYLAND_DISPLAY="wayland-0"

cd /run/user/$USER_UID || exit 1

QX_SOCKET_PATH="/run/display/wayland-container-$DISPLAY_ID"

exec /usr/bin/qxcompositor --wayland-socket-name "$QX_SOCKET_PATH" -o $SCREEN_ORIENTATION