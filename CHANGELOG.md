# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `keycloak:create` provisions a Dokku app, a dedicated PostgreSQL database
  and a production-mode Keycloak (`start --optimized`) with a generated admin
  password. A failed create can be re-run to resume.
- `keycloak:destroy`, `keycloak:info`, `keycloak:list`, `keycloak:start`,
  `keycloak:stop`, `keycloak:restart` and `keycloak:logs`.
- `keycloak:admin-credentials`, the only command that prints the password.
- `keycloak:domains:set` pins Keycloak's hostname to the public domain, and
  `keycloak:letsencrypt` enables TLS through dokku-letsencrypt. Its `--force`
  flag replaces a certificate that is still valid, such as one from the
  staging server.
- `keycloak:config:set`, `config:get` and `config:unset` for `KC_*` and
  `JAVA_OPTS*` settings. Build-time options trigger an image rebuild.
- `keycloak:export` and `keycloak:import` for realm JSON, including over ssh
  through stdin.
- `keycloak:upgrade` backs up the database before moving to another Keycloak
  release, and refuses downgrades.
- Zero-downtime deploys gated on Keycloak's `/health/ready`.
- Keycloak 26.8.1 as the pinned default. Dokku 0.36.0 is the minimum.
- Test suites (bats) and a GitHub Actions workflow running them against
  Dokku in Docker.

[Unreleased]: https://github.com/shebang-labs/dokku-keycloak/commits/main
