PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall test

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"

uninstall:
	rm -f "$(BINDIR)/codex-profile"

test:
	bash -n bin/codex-profile
	bin/codex-profile help >/dev/null
