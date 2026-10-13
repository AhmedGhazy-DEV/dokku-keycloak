#!/usr/bin/env bats
# Runs without Dokku: exercises the DATABASE_URL translation in the image
# entrypoint by asking it to exec `env` instead of kc.sh.

ENTRYPOINT="$BATS_TEST_DIRNAME/../image/docker-entrypoint.sh"

@test "(entrypoint) maps DATABASE_URL to Keycloak settings" {
  run env -i DATABASE_URL="postgres://postgres:s3cret@dokku-postgres-auth-db:5432/auth_db" \
    bash "$ENTRYPOINT" /usr/bin/env
  [ "$status" -eq 0 ]
  [[ "$output" == *"KC_DB_USERNAME=postgres"* ]]
  [[ "$output" == *"KC_DB_PASSWORD=s3cret"* ]]
  [[ "$output" == *"KC_DB_URL=jdbc:postgresql://dokku-postgres-auth-db:5432/auth_db"* ]]
}

@test "(entrypoint) keeps passwords containing @ and :" {
  run env -i DATABASE_URL="postgres://user:p@ss:w0rd@db:5432/kc" bash "$ENTRYPOINT" /usr/bin/env
  [ "$status" -eq 0 ]
  [[ "$output" == *"KC_DB_USERNAME=user"* ]]
  [[ "$output" == *"KC_DB_PASSWORD=p@ss:w0rd"* ]]
  [[ "$output" == *"KC_DB_URL=jdbc:postgresql://db:5432/kc"* ]]
}

@test "(entrypoint) explicit KC_DB_* settings win over DATABASE_URL" {
  run env -i DATABASE_URL="postgres://a:b@db:5432/kc" KC_DB_URL="jdbc:postgresql://other:5432/x" \
    bash "$ENTRYPOINT" /usr/bin/env
  [ "$status" -eq 0 ]
  [[ "$output" == *"KC_DB_URL=jdbc:postgresql://other:5432/x"* ]]
}

@test "(entrypoint) prints nothing of its own" {
  run env -i DATABASE_URL="postgres://a:secretvalue@db:5432/kc" bash "$ENTRYPOINT" /bin/true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
