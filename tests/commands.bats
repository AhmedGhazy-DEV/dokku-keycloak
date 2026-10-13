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
