PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall lint test check path-smoke-test install-smoke-test npm-package-test outreach

install:
	install -d "$(BINDIR)"
	test ! -d "$(BINDIR)/codex-profile"
	test ! -L "$(BINDIR)/codex-profile"
	test ! -d "$(BINDIR)/codex-profiles"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
	ln -sfn codex-profile "$(BINDIR)/codex-profiles"
	test -f "$(BINDIR)/codex-profile"
	test -x "$(BINDIR)/codex-profile"
	test -L "$(BINDIR)/codex-profiles"
	test "$$(readlink "$(BINDIR)/codex-profiles")" = codex-profile

uninstall:
	rm -f "$(BINDIR)/codex-profile" "$(BINDIR)/codex-profiles"

lint:
	scripts/check lint

test:
	scripts/check test

check:
	scripts/check all

path-smoke-test:
	@set -eu; tmp_home="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_home"' EXIT HUP INT TERM; \
		output="$$(HOME="$$tmp_home" bin/codex-profile path default)"; \
		test "$$output" = "$$tmp_home/.codex"; \
		output="$$(HOME="$$tmp_home" bin/codex-profile path personal)"; \
		test "$$output" = "$$tmp_home/.codex-personal"; \
		output="$$(HOME="$$tmp_home" bin/codex-profile path edu)"; \
		test "$$output" = "$$tmp_home/.codex-edu"; \
		output="$$(HOME="$$tmp_home" bin/codex-profile path education)"; \
		test "$$output" = "$$tmp_home/.codex-education"

install-smoke-test:
	@set -eu; tmp_prefix="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_prefix"' EXIT HUP INT TERM; \
		$(MAKE) install PREFIX="$$tmp_prefix" >/dev/null; \
		test -x "$$tmp_prefix/bin/codex-profile"; \
		test -x "$$tmp_prefix/bin/codex-profiles"; \
		"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
		version_output="$$("$$tmp_prefix/bin/codex-profiles" version)"; \
		case "$$version_output" in 'codex-profile '[0-9]*.[0-9]*.[0-9]*) ;; *) exit 1;; esac; \
		$(MAKE) uninstall PREFIX="$$tmp_prefix" >/dev/null; \
		test ! -e "$$tmp_prefix/bin/codex-profile"; \
		test ! -e "$$tmp_prefix/bin/codex-profiles"; \
		test ! -L "$$tmp_prefix/bin/codex-profiles"

npm-package-test:
	bash test/install/npm-package-test.sh

# Operational helper for the outreach tracker (not part of the shipped CLI).
# Usage: make outreach ARGS="list --owned"
outreach:
	node scripts/outreach-tracker.mjs $(ARGS)
