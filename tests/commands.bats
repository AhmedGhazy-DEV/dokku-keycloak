#!/usr/bin/env bats

load test_helper

@test "(keycloak:help) lists the plugin" {
  run dokku keycloak:help
  assert_success
  assert_output_contains "Manage Keycloak instances"
}

@test "(help) includes keycloak in the global listing" {
  run dokku help
  assert_success
  assert_output_contains "keycloak"
}

@test "(keycloak:create) requires a name" {
  run dokku keycloak:create
  assert_failure
  assert_output_contains "Please specify a name"
}

@test "(keycloak:create) rejects invalid names" {
  run dokku keycloak:create "Bad_Name"
  assert_failure
  assert_output_contains "App name must begin with lowercase"
}

@test "(keycloak:create) rejects unknown flags and missing flag values" {
  run dokku keycloak:create "$TEST_APP" --bogus
  assert_failure
  assert_output_contains "Unknown flag: --bogus"

  run dokku keycloak:create "$TEST_APP" --version
  assert_failure
  assert_output_contains "--version requires a value"
}

@test "(keycloak:create) rejects unsafe or unsupported versions" {
  run dokku keycloak:create "$TEST_APP" --version '26.0;rm'
  assert_failure
  assert_output_contains "Invalid Keycloak version"

  run dokku keycloak:create "$TEST_APP" --version 24.0.5
  assert_failure
  assert_output_contains "not supported"
}

@test "(keycloak:create) rejects an invalid memory limit" {
  run dokku keycloak:create "$TEST_APP" --memory lots
  assert_failure
  assert_output_contains "Invalid memory limit"
}

@test "(keycloak:create) refuses to take over an existing app" {
  dokku apps:create "$TEST_APP-plain"
  run dokku keycloak:create "$TEST_APP-plain"
  dokku --force apps:destroy "$TEST_APP-plain"
  assert_failure
  assert_output_contains "not a Keycloak instance"
}

@test "(keycloak:create) leaves no state behind after a validation failure" {
  run dokku keycloak:create "$TEST_APP" --memory lots
  assert_failure
  run dokku keycloak:list
  refute_output_contains "$TEST_APP"
}

@test "(keycloak:info) fails for an unknown instance" {
  run dokku keycloak:info does-not-exist
  assert_failure
  assert_output_contains "Keycloak instance does-not-exist does not exist"
}

@test "(keycloak:info) requires a name" {
  run dokku keycloak:info
  assert_failure
  assert_output_contains "Please specify a Keycloak instance name"
}

@test "(keycloak:list) succeeds and ignores apps not managed by the plugin" {
  dokku apps:create "$TEST_APP-plain"
  run dokku keycloak:list
  dokku --force apps:destroy "$TEST_APP-plain"
  assert_success
  refute_output_contains "$TEST_APP-plain"
}

@test "(lifecycle) every instance command rejects an unknown instance" {
  local subcommand
  for subcommand in start stop restart logs destroy admin-credentials domains:set letsencrypt config:set config:get config:unset export import upgrade; do
    run dokku "keycloak:$subcommand" does-not-exist
    assert_failure
    assert_output_contains "Keycloak instance does-not-exist does not exist"
  done
}

@test "(keycloak:destroy) rejects unknown flags" {
  run dokku keycloak:destroy does-not-exist --yes
  assert_failure
  assert_output_contains "Unknown flag: --yes"
}

@test "(keycloak:letsencrypt) rejects unknown flags and an empty email" {
  run dokku keycloak:letsencrypt does-not-exist --staging
  assert_failure
  assert_output_contains "Unknown flag: --staging"

  run dokku keycloak:letsencrypt does-not-exist --email
  assert_failure
  assert_output_contains "--email requires a value"
}

@test "(keycloak:config:set) rejects flags it does not know" {
  run dokku keycloak:config:set does-not-exist KC_LOG_LEVEL=INFO --restart-now
  assert_failure
  assert_output_contains "Unknown flag: --restart-now"
}

@test "(keycloak:import) rejects unknown flags" {
  run dokku keycloak:import does-not-exist realm.json --merge
  assert_failure
  assert_output_contains "Unknown flag: --merge"
}

@test "(keycloak:upgrade) rejects unknown flags and a missing version value" {
  run dokku keycloak:upgrade does-not-exist --latest
  assert_failure
  assert_output_contains "Unknown flag: --latest"

  run dokku keycloak:upgrade does-not-exist --version
  assert_failure
  assert_output_contains "--version requires a value"
}

@test "(keycloak:help) every entry has exactly one comma separating usage from description" {
  # the help table is split on commas, so a comma inside a description
  # breaks its columns
  source "$BATS_TEST_DIRNAME/../help-functions"
  run fn-keycloak-help-content
  assert_success
  local line
  while IFS= read -r line; do
    [[ "$(tr -cd ',' <<<"$line")" == "," ]] || { echo "bad help line: $line" >&2; return 1; }
  done <<<"$output"
}

@test "(keycloak:letsencrypt) accepts --force" {
  # reaching the instance check proves the flag parsed
  run dokku keycloak:letsencrypt does-not-exist --email ops@example.com --force
  assert_failure
  refute_output_contains "Unknown flag"
  assert_output_contains "Keycloak instance does-not-exist does not exist"
}

@test "(functions) config key lookup is not fooled by SIGPIPE under pipefail" {
  # a writer that keeps printing after the match makes 'cmd | grep -q' fail
  # with SIGPIPE under pipefail; the helper must still find the key
  run bash -c '
    export PLUGIN_CORE_AVAILABLE_PATH="${PLUGIN_CORE_AVAILABLE_PATH:-/var/lib/dokku/core-plugins/available}"
    export PLUGIN_ENABLED_PATH="${PLUGIN_ENABLED_PATH:-/var/lib/dokku/plugins/enabled}"
    export DOKKU_LIB_ROOT="${DOKKU_LIB_ROOT:-/var/lib/dokku}"
    source "$1/functions"
    set -o pipefail
    dokku() { echo KC_WANTED; seq 1 200000; }
    fn-keycloak-has-config-key app KC_WANTED && echo found
    dokku config:keys app | grep -qx KC_WANTED || echo "plain pipe fails too"
  ' _ "$BATS_TEST_DIRNAME/.."
  assert_success
  assert_output_contains "found"
  # proves the stub really triggers the failure the helper avoids
  assert_output_contains "plain pipe fails too"
}
