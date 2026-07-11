PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall lint test path-smoke-test install-smoke-test npm-package-test

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
	shellcheck bin/codex-profile scripts/update-homebrew-formula test/codex-profile-test.sh test/install-script-test.sh test/makefile-smoke-test.sh test/package-metadata-test.sh test/release-helper-test.sh test/release-workflow-test.sh install.sh

test:
	bash -n bin/codex-profile
	bash -n scripts/update-homebrew-formula
	bash -n test/codex-profile-test.sh
	bash -n test/install-script-test.sh
	bash -n test/makefile-smoke-test.sh
	bash -n test/package-metadata-test.sh
	bash -n test/release-helper-test.sh
	bash -n test/release-workflow-test.sh
	sh -n install.sh
	bash test/install-script-test.sh
	bash test/release-workflow-test.sh
	node test/geo-site-test.mjs
	bash test/package-metadata-test.sh
	bash test/release-helper-test.sh
	bin/codex-profile help >/dev/null
	bash test/codex-profile-test.sh
	bash test/makefile-smoke-test.sh
	$(MAKE) path-smoke-test
	$(MAKE) install-smoke-test
	$(MAKE) npm-package-test

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
	@set -eu; tmp_prefix="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_prefix"' EXIT HUP INT TERM; \
		if command -v npm >/dev/null 2>&1; then \
			pack_json="$$(npm pack --json --pack-destination "$$tmp_prefix")"; \
			tarball_name="$$(node -e 'const p=JSON.parse(process.argv[1]); if (!Array.isArray(p) || p.length !== 1 || typeof p[0].filename !== "string") process.exit(1); process.stdout.write(p[0].filename);' "$$pack_json")"; \
			case "$$tarball_name" in ''|*/*) exit 1;; esac; \
			tarball="$$tmp_prefix/$$tarball_name"; \
			test -f "$$tarball"; \
			npm install -g --prefix "$$tmp_prefix" --cache "$$tmp_prefix/npm-cache" "$$tarball" >/dev/null; \
			test -x "$$tmp_prefix/bin/codex-profile"; \
			test -x "$$tmp_prefix/bin/codex-profiles"; \
			test ! -L "$$tmp_prefix/lib/node_modules/codex-profile"; \
			test -f "$$tmp_prefix/lib/node_modules/codex-profile/bin/codex-profile"; \
			test ! -e "$$tmp_prefix/lib/node_modules/codex-profile/media"; \
			"$$tmp_prefix/bin/codex-profile" help >/dev/null; \
			version_output="$$("$$tmp_prefix/bin/codex-profiles" version)"; \
			case "$$version_output" in 'codex-profile '[0-9]*.[0-9]*.[0-9]*) ;; *) exit 1;; esac; \
		else \
			printf '%s\n' 'npm not found; skipping npm package smoke test.'; \
		fi
