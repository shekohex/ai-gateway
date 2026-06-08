#!/bin/sh
set -eu

mkdir -p "${EXECUTOR_DATA_DIR}" "${EXECUTOR_SCOPE_DIR}" "$HOME/.local/share/keyrings" "$XDG_RUNTIME_DIR"
chmod 700 "$HOME/.local/share/keyrings"
chmod 700 "$XDG_RUNTIME_DIR"

eval "$(dbus-launch --sh-syntax)"

printf '%s' "${EXECUTOR_KEYRING_PASSWORD:-}" | gnome-keyring-daemon --unlock --components=secrets >/tmp/keyring.env 2>/dev/null || true
eval "$(gnome-keyring-daemon --start --components=secrets)"

executor web --port "${EXECUTOR_PORT}" --scope "${EXECUTOR_SCOPE_DIR}" &

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
