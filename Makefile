PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall lint test

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"

uninstall:
	rm -f "$(BINDIR)/codex-profile"

lint:
	shellcheck bin/codex-profile test/codex-profile-test.sh

test:
	bash -n bin/codex-profile
	bash -n test/codex-profile-test.sh
	bin/codex-profile help >/dev/null
	bash test/codex-profile-test.sh
	tmp_home="$$(mktemp -d)"; \
		HOME="$$tmp_home" bin/codex-profile path default | grep -E '/\.codex$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path personal | grep -E '/\.codex-personal$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path edu | grep -E '/\.codex-education$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path education | grep -E '/\.codex-education$$' >/dev/null; \
		rm -rf "$$tmp_home"
	tmp_prefix="$$(mktemp -d)"; \
		$(MAKE) install PREFIX="$$tmp_prefix" >/dev/null; \
		test -x "$$tmp_prefix/bin/codex-profile"; \
		"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
		rm -rf "$$tmp_prefix"
