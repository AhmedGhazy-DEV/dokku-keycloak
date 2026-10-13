# Security Policy

## Supported versions

Security fixes are released for the latest minor version of dokku-keycloak.
Keycloak itself is patched by upgrading: `dokku keycloak:upgrade <name>`
moves an instance to the Keycloak release pinned by the installed plugin.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report them privately to **hello@shebanglabs.io**, or through GitHub's
private vulnerability reporting on this repository. Include:

- what is affected (command, file, Dokku and Keycloak versions),
- steps to reproduce or a proof of concept,
- the impact you expect.

We aim to acknowledge reports within 3 working days and to agree on a fix
and disclosure timeline with you. We are happy to credit reporters in the
release notes.

Vulnerabilities in Keycloak, Dokku, dokku-postgres or dokku-letsencrypt
themselves should go to those projects. If you are unsure where an issue
belongs, report it to us and we will help route it.

## What this plugin protects

- The generated admin password is stored in Dokku's property store with
  mode `0600`. It reaches Keycloak only for the first boot, after which it is
  removed from the app config and the container is restarted without it.
- No command except `keycloak:admin-credentials` prints a secret, and
  `keycloak:config:set` never echoes values.
- Keycloak's management port (health and metrics) is not published through
  nginx.
- Pre-upgrade database backups are written with mode `0600` in a `0700`
  directory.

## What it cannot protect

- `dokku --trace` prints configuration values as commands run, including the
  admin and database passwords. Treat trace output as secret.
- Realm exports contain password hashes and client secrets.
- Anyone with root, `docker` group or `dokku` user access on the host can read
  every secret of every instance.
