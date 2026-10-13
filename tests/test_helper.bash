#!/usr/bin/env bash
# shellcheck disable=SC2154 # status and output are set by bats' run
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

# Like refute_output_contains, but never prints the secret it looked for:
# test logs end up in public CI output.
refute_output_contains_secret() {
  if [[ "$output" == *"$1"* ]]; then
    echo "output contains a secret (value withheld); lines:" >&2
    grep -nF -- "$1" <<<"$output" | cut -d: -f1 | tr '\n' ' ' >&2
    echo >&2
    return 1
  fi
}
