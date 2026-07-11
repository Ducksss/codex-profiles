PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall lint test path-smoke-test install-smoke-test npm-package-test

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
	ln -sf codex-profile "$(BINDIR)/codex-profiles"

uninstall:
	rm -f "$(BINDIR)/codex-profile" "$(BINDIR)/codex-profiles"

lint:
	shellcheck bin/codex-profile test/codex-profile-test.sh test/makefile-smoke-test.sh test/package-metadata-test.sh install.sh

test:
	bash -n bin/codex-profile
	bash -n test/codex-profile-test.sh
	bash -n test/makefile-smoke-test.sh
	bash -n test/package-metadata-test.sh
	sh -n install.sh
	node test/geo-site-test.mjs
	bash test/package-metadata-test.sh
	bin/codex-profile help >/dev/null
	bash test/codex-profile-test.sh
	bash test/makefile-smoke-test.sh
	$(MAKE) path-smoke-test
	$(MAKE) install-smoke-test
	$(MAKE) npm-package-test

path-smoke-test:
	@set -eu; tmp_home="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_home"' EXIT HUP INT TERM; \
		HOME="$$tmp_home" bin/codex-profile path default | grep -E '/\.codex$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path personal | grep -E '/\.codex-personal$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path edu | grep -E '/\.codex-edu$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path education | grep -E '/\.codex-education$$' >/dev/null

install-smoke-test:
	@set -eu; tmp_prefix="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_prefix"' EXIT HUP INT TERM; \
		$(MAKE) install PREFIX="$$tmp_prefix" >/dev/null; \
		test -x "$$tmp_prefix/bin/codex-profile"; \
		test -x "$$tmp_prefix/bin/codex-profiles"; \
		"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
		"$$tmp_prefix/bin/codex-profiles" version | grep -E '^codex-profile ' >/dev/null; \
		$(MAKE) uninstall PREFIX="$$tmp_prefix" >/dev/null; \
		test ! -e "$$tmp_prefix/bin/codex-profile"; \
		test ! -e "$$tmp_prefix/bin/codex-profiles"; \
		test ! -L "$$tmp_prefix/bin/codex-profiles"

npm-package-test:
	@set -eu; tmp_prefix="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_prefix"' EXIT HUP INT TERM; \
		if command -v npm >/dev/null 2>&1; then \
			npm pack --dry-run --silent >/dev/null; \
			npm install -g --prefix "$$tmp_prefix" --cache "$$tmp_prefix/npm-cache" . >/dev/null; \
			test -x "$$tmp_prefix/bin/codex-profile"; \
			test -x "$$tmp_prefix/bin/codex-profiles"; \
			"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
			"$$tmp_prefix/bin/codex-profiles" version | grep -E '^codex-profile ' >/dev/null; \
		else \
			printf '%s\n' 'npm not found; skipping npm package smoke test.'; \
		fi
