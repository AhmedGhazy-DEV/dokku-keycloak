SHELL_FILES := commands config dependencies functions help-functions install \
	$(wildcard post-*) $(wildcard subcommands/*) $(wildcard image/*.sh) \
	$(wildcard tests/*.bash)

.PHONY: lint test test-e2e

lint:
	shellcheck -x $(SHELL_FILES)

# Fast checks: argument handling and failure paths. Needs a Dokku host with
# this plugin installed.
test:
	bats tests/commands.bats

# Full lifecycle against a real Keycloak; takes several minutes.
test-e2e:
	bats tests/lifecycle.bats
