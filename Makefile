current_dir:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
name ?= shell-timeout
version:=$(shell grep Version: $(name).spec | awk '{print $$2}')

_default:
	@echo "Perhaps you want:"
	@echo "  make test"
	@echo "  make sources"
	@echo "  make srpm"
	@echo "  make rpm"

sources:
	@echo "You found my koji hook"
	@mkdir -p build/$(name)-$(version)/src/
	@cp src/* build/$(name)-$(version)/src/
	@mkdir -p build/$(name)-$(version)/conf/
	@cp conf/* build/$(name)-$(version)/conf/
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

# TODO: make this smart enough to find and include test- targets
test: test-simple-config test-tmout-is-float test-tmout-is-negative test-tmout-is-not-readonly test-tmout-is-readonly test-tmout-is-unset test-tmout-is-zero test-config-includes-change-readonly test-config-includes-change-tmout test-config-includes-conf-only test-config-includes-extra-gid test-config-includes-extra-gid-removes-gid test-config-includes-extra-uid test-config-includes-extra-uid-removes-uid

test-basic-syntax:
	@echo ''
	@echo '--------------------------------'
	@echo 'test bash script syntax'
	@echo '--------------------------------'
	bash -n $(current_dir)/src/shell-timeout.sh

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
