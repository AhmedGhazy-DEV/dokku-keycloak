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
