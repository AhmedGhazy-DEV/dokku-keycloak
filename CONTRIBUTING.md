# Contributing to dokku-keycloak

Thanks for helping improve dokku-keycloak. Bug reports, fixes, docs and
tests are all welcome. Please read the [Code of Conduct](CODE_OF_CONDUCT.md)
first. Report security issues privately as described in
[SECURITY.md](SECURITY.md), not in public issues.

## How changes are made

- Open an issue before large changes so the design can be agreed first.
- Work on a short-lived branch named after the change, for example
  `feat/realm-roles` or `fix/proxy-headers`.
- Keep commits small and atomic; every commit should leave the plugin
  working.
- Use [Conventional Commits](https://www.conventionalcommits.org/):
  `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`, `refactor:`. Keep the
  subject imperative and under 72 characters, and explain the *why* in the
  body when it is not obvious.
- Add a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md) for anything
  users will notice.
- `make lint` and the test suites must pass.

## Code style

- Pure Bash with `set -eo pipefail`, checked by `shellcheck` with no
  warnings. `.shellcheckrc` explains the few checks that are disabled.
- Reuse Dokku's helpers (`dokku_log_info1`, `dokku_log_fail`,
  `is_valid_app_name`, the property store) instead of reimplementing them.
- Follow Dokku's plugin layout: one file per command in `subcommands/`,
  shared code in `functions`, constants in `config`.
- Never print secrets. `keycloak:admin-credentials` is the only exception.
- Every command must be safe to re-run and must exit non-zero with a clear
  message on failure.

## Local development environment

Dokku needs an Ubuntu or Debian host. On macOS, or to keep your workstation
untouched, use a disposable [Multipass](https://multipass.run) VM. The steps
below are the setup this project is developed and tested with.

### 1. Create the VM and install Dokku

```sh
multipass launch 24.04 --name dokku-kc --cpus 2 --memory 4G --disk 20G
multipass mount "$PWD" dokku-kc:/opt/dokku-keycloak   # run from the repository root

multipass shell dokku-kc
wget -NP . https://dokku.com/install/v0.38.31/bootstrap.sh
sudo DOKKU_TAG=v0.38.31 bash bootstrap.sh
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git letsencrypt
sudo apt-get install -y shellcheck bats make
```

Keycloak needs about 1.5 GB of memory per instance, so give the VM at least
4 GB. The repository is mounted under `/opt` because the `dokku` user cannot
read files in `/home/ubuntu`.

### 2. Install the plugin from your working copy

To test the committed state exactly as users install it:

```sh
sudo dokku plugin:install file:///opt/dokku-keycloak keycloak
```

While developing, link the working copy instead so edits apply immediately:

```sh
sudo rm -rf /var/lib/dokku/plugins/available/keycloak
sudo ln -s /opt/dokku-keycloak /var/lib/dokku/plugins/available/keycloak
sudo dokku plugin:install   # re-runs the install triggers
```

### 3. Domains without DNS: sslip.io

[sslip.io](https://sslip.io) resolves any name that embeds an IP address to
that address, so the VM IP gives you working domains with no DNS setup.
With the VM at, say, `192.0.2.10` (find yours with `multipass list`):

```sh
dokku keycloak:create auth
dokku keycloak:domains:set auth auth.192-0-2-10.sslip.io
```

`http://auth.192-0-2-10.sslip.io/admin/` then opens from the host, and
`dokku keycloak:admin-credentials auth` prints the login.

### 4. TLS without Let's Encrypt

Let's Encrypt cannot reach a private VM, so **do not request real
certificates locally**. Install a self-signed certificate instead. Dokku's
nginx serves it exactly like an issued one, so the HTTPS redirect, HSTS and
Keycloak's `https://` issuer can all be checked:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -subj "/CN=auth.192-0-2-10.sslip.io" \
  -addext "subjectAltName=DNS:auth.192-0-2-10.sslip.io" \
  -keyout kc.key -out kc.crt
chmod 644 kc.key          # the dokku user must be able to read it
dokku certs:add auth kc.crt kc.key
```

`dokku certs:generate auth auth.192-0-2-10.sslip.io` works too, but asks
for the certificate details interactively. If you have
[mkcert](https://github.com/FiloSottile/mkcert) on your workstation, a
certificate from it is trusted by your browser with no warning. Remove the
certificate afterwards with `dokku certs:remove auth`.

For `keycloak:letsencrypt`, test only the parts that do not need the ACME
server. A missing email must fail with the fix, flags must be validated,
and a failing `letsencrypt:enable` must surface as a non-zero exit.

### 5. Email: Mailpit

[Mailpit](https://mailpit.axllent.org) accepts all mail and shows it in a
web UI. Run it inside the VM, listening on the Docker bridge so Keycloak
containers can reach it:

```sh
sudo docker run -d --name mailpit --restart unless-stopped \
  -p 172.17.0.1:1025:1025 -p 8025:8025 axllent/mailpit:v1.31.5
```

In the Keycloak admin console, set the realm's email settings to host
`172.17.0.1`, port `1025`, no authentication and no TLS, then use
**Test connection**. Messages appear at `http://<vm-ip>:8025`.

## Running the tests

Run these inside the VM, from `/opt/dokku-keycloak`, with the plugin
installed:

| Command          | What it covers                                            | Time      |
| ---------------- | --------------------------------------------------------- | --------- |
| `make lint`      | `shellcheck` on every script                              | seconds   |
| `make test`      | Entrypoint unit tests, argument handling, failure paths   | ~1 minute |
| `make test-e2e`  | A real instance from create to destroy, including upgrade | ~4 minutes |

The end-to-end suite uses Mailpit at `http://127.0.0.1:8025` when it is
running and skips the mail test otherwise. Set `KEYCLOAK_TEST_MAILPIT_API`
to point it elsewhere.

CI runs the same suites against Dokku in Docker, on the oldest supported
release and the current stable one. You can reproduce that anywhere Docker
runs:

```sh
tests/dokku-in-docker.sh 0.38.31
docker exec dokku bash -c 'cd /tmp/dokku-keycloak && make test test-e2e'
```

Next to an existing Dokku install, pass `DOKKU_CONTAINER`,
`DOKKU_HOST_DIR`, `TEST_APP` and `E2E_APP` so the two do not collide.

## Pull requests

Fill in the pull request template, link the issue, and describe how you
tested the change. A maintainer from [Shebang Labs](https://shebanglabs.io)
will review it.
