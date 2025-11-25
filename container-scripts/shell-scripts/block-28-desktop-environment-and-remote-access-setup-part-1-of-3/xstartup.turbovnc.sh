#!/bin/sh
# Optimized TurboVNC xstartup for XFCE + GPU
# Official TurboVNC docs: https://rawcdn.githack.com/TurboVNC/turbovnc/3.2.1/doc/index.html
# Official VirtualGL docs: https://rawcdn.githack.com/VirtualGL/virtualgl/3.1.4/doc/index.html

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS
  export DBUS_SESSION_BUS_PID
fi

# Performance: Disable compositing (critical for VNC)
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# Disable window manager shadows/effects
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Disable bell
xset b off 2>/dev/null || true

# Set keyboard repeat rate (faster responsiveness)
xset r rate 250 30 2>/dev/null || true


# Start window manager with optimizations
export XFWM4_USE_PRESENT=0  # Disable Present extension (can cause issues)

# Start XFCE
exec startxfce4
