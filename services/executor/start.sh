#!/bin/sh
set -eu

mkdir -p "${EXECUTOR_DATA_DIR}" "${EXECUTOR_SCOPE_DIR}" "$HOME/.local/share/keyrings" "$XDG_RUNTIME_DIR"
chmod 700 "$HOME"
chmod 700 "$HOME/.local/share/keyrings"
chmod 700 "$XDG_RUNTIME_DIR"

eval "$(dbus-launch --sh-syntax)"

eval "$(printf '%s\n' "${EXECUTOR_KEYRING_PASSWORD:-}" | gnome-keyring-daemon --unlock --components=secrets 2>/tmp/keyring.err)"

keyring_ready=0
for _ in $(seq 1 50); do
  if printf '%s' probe | secret-tool store --label='Executor keyring probe' executor probe >/dev/null 2>&1; then
    secret-tool clear executor probe >/dev/null 2>&1 || true
    keyring_ready=1
    break
  fi
  sleep 0.1
done

if [ "$keyring_ready" -ne 1 ]; then
  echo "Secret Service unavailable; executor keychain would not persist secrets" >&2
  cat /tmp/keyring.err >&2 || true
  exit 1
fi

executor daemon run --foreground --port "${EXECUTOR_PORT}" --scope "${EXECUTOR_SCOPE_DIR}" --log-level "debug" &

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
