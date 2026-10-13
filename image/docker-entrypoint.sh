#!/bin/bash
# Translates the DATABASE_URL set by `dokku postgres:link` into Keycloak's own
# settings, then hands over to kc.sh. Credentials are never printed.
set -euo pipefail

if [[ -n "${DATABASE_URL:-}" ]]; then
  url="${DATABASE_URL#*://}"
  # split on the last "@" and first ":" so passwords may contain either
  creds="${url%@*}"
  export KC_DB_USERNAME="${KC_DB_USERNAME:-${creds%%:*}}"
  export KC_DB_PASSWORD="${KC_DB_PASSWORD:-${creds#*:}}"
  export KC_DB_URL="${KC_DB_URL:-jdbc:postgresql://${url##*@}}"
fi

# An absolute path runs as-is (export and import use this); anything else is
# a kc.sh subcommand, which keeps `dokku run <app> show-config` working.
if [[ "${1:-}" == /* ]]; then
  exec "$@"
fi
exec /opt/keycloak/bin/kc.sh "$@"
