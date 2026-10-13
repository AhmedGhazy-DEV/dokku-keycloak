#!/usr/bin/env bash
# Shared helpers for the bats suites. Tests drive the real `dokku` binary, so
# they must run on a Dokku host with this plugin installed.

export TEST_APP="${TEST_APP:-kc-test}"

assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "expected success, got status $status. output:" >&2
    echo "$output" >&2
    return 1
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "expected failure, got success. output:" >&2
    echo "$output" >&2
    return 1
  fi
}

assert_output_contains() {
  if [[ "$output" != *"$1"* ]]; then
    echo "expected output to contain: $1" >&2
    echo "actual output:" >&2
    echo "$output" >&2
    return 1
  fi
}

refute_output_contains() {
  if [[ "$output" == *"$1"* ]]; then
    echo "expected output not to contain: $1" >&2
    echo "$output" >&2
    return 1
  fi
}
