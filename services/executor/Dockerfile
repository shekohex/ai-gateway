FROM node:24-bookworm-slim

ARG EXECUTOR_VERSION=latest

ENV EXECUTOR_PORT=4788
ENV EXECUTOR_DATA_DIR=/var/lib/executor
ENV EXECUTOR_SCOPE_DIR=/workspace
ENV HOME=/var/lib/executor/home
ENV XDG_RUNTIME_DIR=/tmp/runtime-executor

RUN apt-get update && apt-get install -y --no-install-recommends \
    caddy \
    dbus-x11 \
    gnome-keyring \
    libsecret-tools \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g "executor@${EXECUTOR_VERSION}"
RUN executor --help >/dev/null

WORKDIR /workspace

COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /usr/local/bin/start-executor-proxy

RUN chmod +x /usr/local/bin/start-executor-proxy \
  && mkdir -p /var/lib/executor /workspace "$HOME/.local/share/keyrings" "$XDG_RUNTIME_DIR" \
  && chmod 700 "$HOME" \
  && chmod 700 "$HOME/.local/share/keyrings" \
  && chmod 700 "$XDG_RUNTIME_DIR"

VOLUME ["/var/lib/executor", "/workspace"]

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/start-executor-proxy"]
