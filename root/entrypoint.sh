#!/usr/bin/env bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
TZ="${TZ:-Etc/UTC}"

if [[ -f "/usr/share/zoneinfo/${TZ}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
fi

mkdir -p /config /music /downloads

if [[ ! -f /config/config.yaml ]]; then
  cp /defaults/config.yaml /config/config.yaml
fi
if [[ ! -f /config/beets.sh ]]; then
  cp /defaults/beets.sh /config/beets.sh
fi
chmod +x /config/beets.sh

if [[ "$(id -u)" -eq 0 ]]; then
  if getent group "${PGID}" >/dev/null 2>&1; then
    EXISTING_GROUP="$(getent group "${PGID}" | cut -d: -f1)"
    if [[ "${EXISTING_GROUP}" != "abc" ]]; then
      usermod -g "${PGID}" abc
    fi
  else
    groupmod -o -g "${PGID}" abc
  fi
  usermod -o -u "${PUID}" abc >/dev/null 2>&1 || true
  chown -R abc:abc /config
  chown abc:abc /music /downloads

  if [[ "$#" -eq 0 ]]; then
    set -- web
  fi
  exec gosu abc:abc beet "$@"
fi

if [[ "$#" -eq 0 ]]; then
  set -- web
fi
exec beet "$@"
