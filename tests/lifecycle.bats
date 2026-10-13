#!/usr/bin/env bats
# End-to-end lifecycle of one real Keycloak instance. Slow (several minutes):
# it creates an instance on an older release so the upgrade path is real.
# Needs a Dokku host with dokku-postgres and dokku-letsencrypt installed.
# The SMTP test also needs Mailpit (see CONTRIBUTING.md) and is skipped
# without it.

load test_helper

E2E_APP="${E2E_APP:-kc-e2e}"
FROM_VERSION="${KEYCLOAK_E2E_FROM_VERSION:-26.8.0}"
SMTP_HOST="${KEYCLOAK_TEST_SMTP_HOST:-172.17.0.1}"
MAILPIT_API="${KEYCLOAK_TEST_MAILPIT_API:-http://127.0.0.1:8025}"

domain() {
  echo "$E2E_APP.$(hostname -I | awk '{print $1}' | tr . -).sslip.io"
}

# Requests go to the local nginx with the instance's Host header, so tests do
# not depend on DNS.
kc_curl() {
  curl -s --retry 10 --retry-all-errors --retry-delay 2 -H "Host: $(domain)" "$@"
}

admin_password() {
  dokku keycloak:admin-credentials "$E2E_APP" 2>/dev/null | awk '/^Password:/ {print $2}'
}

admin_token() {
  kc_curl http://127.0.0.1/realms/master/protocol/openid-connect/token \
    -d grant_type=password -d client_id=admin-cli -d username=admin \
    --data-urlencode "password=$(admin_password)" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'
}

kc_admin() {
  local method="$1" path="$2"
  shift 2
  kc_curl -X "$method" -H "Authorization: Bearer $(admin_token)" -H 'Content-Type: application/json' \
    "http://127.0.0.1/admin$path" "$@"
}

setup_file() {
  dokku keycloak:destroy "$E2E_APP" --force >/dev/null 2>&1 || true
  dokku keycloak:create "$E2E_APP" --version "$FROM_VERSION" >"$BATS_FILE_TMPDIR/create.log" 2>&1
  # every request below is sent with this Host header
  dokku keycloak:domains:set "$E2E_APP" "$(domain)" >/dev/null 2>&1
}

teardown_file() {
  dokku keycloak:destroy "$E2E_APP" --force >/dev/null 2>&1 || true
  # destroy keeps pre-upgrade backups on purpose; the test's are disposable
  rm -rf "${DOKKU_LIB_ROOT:-/var/lib/dokku}/data/keycloak/$E2E_APP"
  dokku letsencrypt:set "$E2E_APP" email >/dev/null 2>&1 || true
}

@test "(e2e) create produces a running, listed instance" {
  run dokku keycloak:list
  assert_success
  assert_output_contains "$E2E_APP"

  run dokku keycloak:info "$E2E_APP"
  assert_success
  assert_output_contains "Running:        true"
  assert_output_contains "Version:        $FROM_VERSION"
}

@test "(e2e) create never prints the database password" {
  local db_password
  db_password="$(dokku config:get "$E2E_APP" DATABASE_URL | sed 's#^[^:]*://[^:]*:\([^@]*\)@.*#\1#')"
  [[ ${#db_password} -ge 8 ]]

  run cat "$BATS_FILE_TMPDIR/create.log"
  refute_output_contains_secret "$db_password"
}

@test "(e2e) the admin password never appears outside admin-credentials" {
  local password
  password="$(admin_password)"
  [[ ${#password} -ge 32 ]]

  run cat "$BATS_FILE_TMPDIR/create.log"
  refute_output_contains_secret "$password"
  run dokku keycloak:info "$E2E_APP"
  refute_output_contains_secret "$password"
  run dokku config:show "$E2E_APP"
  refute_output_contains_secret "$password"
}

@test "(e2e) the admin can log in and the management port is not public" {
  [[ -n "$(admin_token)" ]]

  run kc_curl -o /dev/null -w '%{http_code}' http://127.0.0.1/health/ready
  [[ "$output" == "404" ]]
}

@test "(e2e) Keycloak runs as PID 1 so shutdown signals reach it" {
  run cat "$BATS_FILE_TMPDIR/create.log"
  refute_output_contains "not PID 1"

  run dokku scheduler-docker-local:report "$E2E_APP" --scheduler-docker-local-init-process
  [[ "$output" == "false" ]]
}

@test "(e2e) creating the same instance again fails without side effects" {
  run dokku keycloak:create "$E2E_APP"
  assert_failure
  assert_output_contains "already exists"
}

@test "(e2e) domains:set pins the token issuer to the public hostname" {
  run dokku keycloak:config:get "$E2E_APP" KC_HOSTNAME
  [[ "$output" == "$(domain)" ]]

  run kc_curl http://127.0.0.1/realms/master/.well-known/openid-configuration
  assert_output_contains "\"issuer\":\"http://$(domain)/realms/master\""

  run dokku keycloak:domains:set "$E2E_APP" "$(domain)"
  assert_success
  assert_output_contains "already"
}

@test "(e2e) config set, get and unset round-trip without echoing values" {
  run dokku keycloak:config:set "$E2E_APP" KC_SPI_E2E_MARKER=marker-7f3a91 KC_LOG_LEVEL=WARN
  assert_success
  refute_output_contains "marker-7f3a91"

  run dokku keycloak:config:get "$E2E_APP" KC_LOG_LEVEL
  assert_success
  [[ "$output" == "WARN" ]]

  run dokku keycloak:config:set "$E2E_APP" KC_LOG_LEVEL=WARN
  assert_output_contains "No changes"

  run dokku keycloak:config:unset "$E2E_APP" KC_LOG_LEVEL KC_SPI_E2E_MARKER
  assert_success
  run dokku keycloak:config:get "$E2E_APP" KC_LOG_LEVEL
  assert_failure
}

@test "(e2e) Keycloak delivers mail through the configured SMTP server" {
  curl -fs "$MAILPIT_API/api/v1/info" >/dev/null || skip "Mailpit is not running"
  curl -fs -X DELETE "$MAILPIT_API/api/v1/messages" >/dev/null

  local admin_id
  admin_id="$(kc_admin GET '/realms/master/users?username=admin&exact=true' | sed -n 's/^\[{"id":"\([^"]*\)".*/\1/p')"
  kc_admin PUT "/realms/master/users/$admin_id" -d '{"email":"admin@example.com","firstName":"Admin","lastName":"User"}'

  run kc_admin POST /realms/master/testSMTPConnection -o /dev/null -w '%{http_code}' \
    -d "{\"host\":\"$SMTP_HOST\",\"port\":\"1025\",\"from\":\"keycloak@example.com\"}"
  [[ "$output" == "204" ]]

  run curl -fs "$MAILPIT_API/api/v1/messages"
  assert_output_contains "admin@example.com"
}

@test "(e2e) a realm survives export, modification and import --override" {
  kc_admin POST /realms -d '{"realm":"e2e","enabled":true,"displayName":"Original"}'

  dokku keycloak:export "$E2E_APP" e2e >"$BATS_FILE_TMPDIR/e2e.json"
  run grep -c '"realm" : "e2e"' "$BATS_FILE_TMPDIR/e2e.json"
  [[ "$output" -ge 1 ]]

  kc_admin PUT /realms/e2e -d '{"displayName":"Changed"}'

  run bash -c "dokku keycloak:import $E2E_APP - < $BATS_FILE_TMPDIR/e2e.json"
  assert_success
  run kc_admin GET /realms/e2e
  assert_output_contains '"displayName":"Changed"'

  run bash -c "dokku keycloak:import $E2E_APP - --override < $BATS_FILE_TMPDIR/e2e.json"
  assert_success
  run kc_admin GET /realms/e2e
  assert_output_contains '"displayName":"Original"'
}

@test "(e2e) stop, start and restart keep the instance usable" {
  run dokku keycloak:stop "$E2E_APP"
  assert_success
  run dokku keycloak:info "$E2E_APP"
  assert_output_contains "Running:        false"

  run dokku keycloak:start "$E2E_APP"
  assert_success
  run dokku keycloak:restart "$E2E_APP"
  assert_success
  [[ -n "$(admin_token)" ]]
}

@test "(e2e) upgrade backs up the database and keeps realms" {
  run dokku keycloak:upgrade "$E2E_APP"
  assert_success
  assert_output_contains "Backing up database"

  run dokku keycloak:info "$E2E_APP"
  assert_output_contains "Running:        true"
  refute_output_contains "Version:        $FROM_VERSION"

  run kc_curl -o /dev/null -w '%{http_code}' http://127.0.0.1/realms/e2e
  [[ "$output" == "200" ]]

  run dokku keycloak:upgrade "$E2E_APP" --version "$FROM_VERSION"
  assert_failure
  assert_output_contains "Refusing to downgrade"
}

@test "(e2e) letsencrypt explains a missing email instead of requesting a certificate" {
  dokku letsencrypt:report --global --letsencrypt-global-email | grep -q . && skip "a global Let's Encrypt email is set"
  run dokku keycloak:letsencrypt "$E2E_APP"
  assert_failure
  assert_output_contains "needs a contact email"
}

@test "(e2e) destroy needs confirmation, then removes the app and database" {
  run bash -c "echo wrong | dokku keycloak:destroy $E2E_APP"
  assert_failure
  assert_output_contains "Aborted"

  run dokku keycloak:destroy "$E2E_APP" --force
  assert_success
  run dokku postgres:exists "$E2E_APP-db"
  assert_failure
  run dokku keycloak:list
  refute_output_contains "$E2E_APP"
}
