PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall lint test npm-package-test

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
	ln -sf codex-profile "$(BINDIR)/codex-profiles"

uninstall:
	rm -f "$(BINDIR)/codex-profile" "$(BINDIR)/codex-profiles"

lint:
	shellcheck bin/codex-profile test/codex-profile-test.sh test/package-metadata-test.sh install.sh

test:
	bash -n bin/codex-profile
	bash -n test/codex-profile-test.sh
	bash -n test/package-metadata-test.sh
	sh -n install.sh
	node test/geo-site-test.mjs
	bash test/package-metadata-test.sh
	bin/codex-profile help >/dev/null
	bash test/codex-profile-test.sh
	tmp_home="$$(mktemp -d)"; \
		HOME="$$tmp_home" bin/codex-profile path default | grep -E '/\.codex$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path personal | grep -E '/\.codex-personal$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path edu | grep -E '/\.codex-edu$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path education | grep -E '/\.codex-education$$' >/dev/null; \
		rm -rf "$$tmp_home"
	tmp_prefix="$$(mktemp -d)"; \
		$(MAKE) install PREFIX="$$tmp_prefix" >/dev/null; \
		test -x "$$tmp_prefix/bin/codex-profile"; \
		test -x "$$tmp_prefix/bin/codex-profiles"; \
		"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
		"$$tmp_prefix/bin/codex-profiles" version | grep -E '^codex-profile ' >/dev/null; \
		$(MAKE) uninstall PREFIX="$$tmp_prefix" >/dev/null; \
		test ! -e "$$tmp_prefix/bin/codex-profile"; \
		test ! -e "$$tmp_prefix/bin/codex-profiles"; \
		test ! -L "$$tmp_prefix/bin/codex-profiles"; \
		rm -rf "$$tmp_prefix"
	$(MAKE) npm-package-test

npm-package-test:
	@if command -v npm >/dev/null 2>&1; then \
		tmp_prefix="$$(mktemp -d)"; \
		npm pack --dry-run --silent >/dev/null; \
		npm install -g --prefix "$$tmp_prefix" --cache "$$tmp_prefix/npm-cache" . >/dev/null; \
		test -x "$$tmp_prefix/bin/codex-profile"; \
		test -x "$$tmp_prefix/bin/codex-profiles"; \
		"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
		"$$tmp_prefix/bin/codex-profiles" version | grep -E '^codex-profile ' >/dev/null; \
		rm -rf "$$tmp_prefix"; \
	else \
		printf '%s\n' 'npm not found; skipping npm package smoke test.'; \
	fi
