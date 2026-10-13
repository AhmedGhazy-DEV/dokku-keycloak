#!/usr/bin/env bash
# Starts Dokku in Docker with dokku-postgres, dokku-letsencrypt and this
# plugin installed, the way CI runs the test suites.
#
#   tests/dokku-in-docker.sh <dokku-version>
#   docker exec dokku bash -c 'cd /tmp/dokku-keycloak && make test test-e2e'
#
# DOKKU_CONTAINER and DOKKU_HOST_DIR allow running it next to an existing
# Dokku install. The plugin is installed from the committed HEAD.
set -eo pipefail

VERSION="${1:?usage: $0 <dokku-version>}"
NAME="${DOKKU_CONTAINER:-dokku}"
HOST_DIR="${DOKKU_HOST_DIR:-/var/lib/dokku}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker run -d --name "$NAME" \
  --env DOKKU_HOSTNAME=dokku.test \
  --env DOKKU_HOST_ROOT="$HOST_DIR/home/dokku" \
  --env DOKKU_LIB_HOST_ROOT="$HOST_DIR/var/lib/dokku" \
  --volume "$HOST_DIR:/mnt/dokku" \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  "dokku/dokku:$VERSION" >/dev/null

for _ in $(seq 1 60); do
  docker exec "$NAME" dokku version >/dev/null 2>&1 && break
  sleep 2
done

docker exec "$NAME" bash -c 'apt-get update -qq && apt-get install -y -qq bats curl make >/dev/null'
docker exec "$NAME" dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
docker exec "$NAME" dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git letsencrypt
docker cp "$ROOT" "$NAME:/tmp/dokku-keycloak"
# docker cp keeps host ownership, which git refuses to clone from
docker exec "$NAME" git config --system --add safe.directory '*'
docker exec "$NAME" dokku plugin:install file:///tmp/dokku-keycloak keycloak
docker exec "$NAME" dokku plugin:list
