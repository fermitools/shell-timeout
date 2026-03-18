current_dir:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
name ?= shell-timeout
version:=$(shell grep Version: $(name).spec | awk '{print $$2}')

ASCIIDOCTOR := $(shell command -v asciidoctor 2>/dev/null)
ASCIIDOC    := $(shell command -v asciidoc    2>/dev/null)

_default:
	@echo "Perhaps you want:"
	@echo "  make test"
	@echo "  make man"
	@echo "  make sources"
	@echo "  make srpm"
	@echo "  make rpm"

man: man/shell-timeout.conf.5

man/shell-timeout.conf.5: docs/shell-timeout.conf.5.adoc
	@mkdir -p man
ifdef ASCIIDOCTOR
	asciidoctor -b manpage -o $@ $<
else ifdef ASCIIDOC
	asciidoc -b manpage -o $@ $<
else
	$(error Neither asciidoctor nor asciidoc found; install one to build the man page)
endif

sources: man
	@echo "You found my koji hook"
	@mkdir -p build/$(name)-$(version)/src/
	@cp src/* build/$(name)-$(version)/src/
	@mkdir -p build/$(name)-$(version)/conf/
	@cp conf/* build/$(name)-$(version)/conf/
	@mkdir -p build/$(name)-$(version)/docs/
	@cp docs/* build/$(name)-$(version)/docs/
	@mkdir -p build/$(name)-$(version)/man/
	@cp man/shell-timeout.conf.5 build/$(name)-$(version)/man/
	@cp README.md build/$(name)-$(version)/
	@cp LICENSE build/$(name)-$(version)/
	cd build ; tar cf - $(name)-$(version) | gzip --best > $(current_dir)/$(version).tar.gz
	rm -rf build

srpm: sources
	@echo "You found my copr hook"
	rpmbuild -bs --define '_sourcedir $(current_dir)' --define '_srcrpmdir $(current_dir)/SRPMS' $(name).spec

rpm: sources
	@echo "You found my 'just build it' hook"
	rpmbuild -bb --define '_rpmdir $(current_dir)/RPMS' --define '_builddir $(current_dir)/BUILD' --define '_sourcedir $(current_dir)' $(name).spec

TEST_TARGETS := $(shell grep -E '^test-[a-zA-Z0-9_-]+:' $(firstword $(MAKEFILE_LIST)) | cut -d: -f1 | sort -u)
test: $(TEST_TARGETS)

test-basic-syntax:
	@echo ''
	@echo '--------------------------------'
	@echo 'test bash script syntax'
	@echo '--------------------------------'
	bash -n $(current_dir)/src/shell-timeout.sh

test-shellcheck: test-basic-syntax
	@echo ''
	@echo '--------------------------------'
	@echo 'test shellcheck'
	@echo '--------------------------------'
	shellcheck $(current_dir)/src/shell-timeout.sh

test-shfmt: test-basic-syntax
	@echo ''
	@echo '--------------------------------'
	@echo 'test shfmt'
	@echo '--------------------------------'
	shfmt -d -i 4 -ci $(current_dir)/src/shell-timeout.sh

test-setup-podman: | test-basic-syntax
	@echo ''
	@echo '--------------------------------'
	@echo 'test podman actually works'
	@echo '--------------------------------'
	podman run --pull=newer --rm -it fedora:latest echo "podman works"

test-build-test-container: | test-setup-podman
	@echo ''
	@echo '--------------------------------'
	@echo 'build our test container'
	@echo '--------------------------------'
	podman build -t shell-timeout:latest -f tests/Dockerfile

test-simple-config: test-basic-syntax | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test simple config'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/simple-config:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-float: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is a float'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-float:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'


test-tmout-is-negative: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is negative'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-negative:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-not-readonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is NOT read only'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-not-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-readonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is read only'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'

test-tmout-is-unset: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is unset'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-unset:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-zero: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test timeout is zero'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-zero:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-change-readonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes change to read only'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-readonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'

test-config-includes-change-tmout: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes change to tmout'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x30x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x30x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x30x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x30x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^1$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^1$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^1$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^1$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-change-tmout:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-conf-only: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes only .conf files'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-conf-only:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-extra-gid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes extra gid'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-extra-gid-removes-gid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes extra gid drops another'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-gid-removes-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-extra-uid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes extra uid'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-extra-uid-removes-uid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes extra uid drops another'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0    --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-extra-uid-removes-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'




test-config-includes-username: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes username'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-username-removes-username: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes username drops another'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 5555:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-groupname: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes groupname'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'

test-config-includes-groupname-removes-groupname: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test config includes groupname drops another'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# zsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	# csh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	# tcsh
	podman run -u 0:0     --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:3000  --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'


test-config-includes-uid-removes-by-username: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test uid added numerically removed via username'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-uid-removes-by-username:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-username-removes-by-uid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test username added by name removed via numeric uid'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-username-removes-by-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-gid-removes-by-groupname: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test gid added numerically removed via groupname'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-gid-removes-by-groupname:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-config-includes-groupname-removes-by-gid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test groupname added by name removed via numeric gid'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/config-includes-groupname-removes-by-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-uid-nocheck-does-not-affect-gid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test uid nocheck does not prevent gid match'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/uid-nocheck-does-not-affect-gid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-gid-nocheck-does-not-affect-uid: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test gid nocheck does not prevent uid match'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/gid-nocheck-does-not-affect-uid:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-readonly-uid-noreadonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test readonly with uid exempt from readonly'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-uid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-readonly-gid-noreadonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test readonly with gid exempt from readonly'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-gid-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-readonly-username-noreadonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test readonly with username resolved to uid exempt from readonly'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-username-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'

test-tmout-is-readonly-groupname-noreadonly: | test-build-test-container
	@echo ''
	@echo '--------------------------------'
	@echo 'test readonly with groupname resolved to gid exempt from readonly'
	@echo '--------------------------------'
	# bash
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'readonly'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'source /shell-timeout.sh; unset TMOUT'
	# zsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q xx
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; echo "x$${TMOUT}x"' | grep -q x900x
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT' 2>&1 | grep -q 'read-only'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.sh:/shell-timeout.sh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/zsh -c 'source /shell-timeout.sh; unset TMOUT'
	# csh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'csh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
	# tcsh
	podman run -u 0:0   --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep -c autologout | grep -q '^0$$'
	podman run -u 0:2000 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1000:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; set"' | grep autologout | grep -q '[[:space:]]15$$'
	podman run -u 1001:0 --rm -v "$(current_dir)/src/shell-timeout.csh:/shell-timeout.csh:ro,z" -v "$(current_dir)/tests/tmout-is-readonly-groupname-noreadonly:/etc/default:ro,z" shell-timeout:latest /bin/bash -c 'tcsh -c "source /shell-timeout.csh; unset autologout"' | grep -c autologout | grep -q '^0$$'
