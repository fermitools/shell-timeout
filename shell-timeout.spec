# test suite runs a bunch of podman, can't really do that within the rpm buildroot in koji
%bcond tests 0

Name:		shell-timeout
Version:	0.1.0
Release:	1%{?dist}
BuildArch:	noarch

License:	GPL-3.0-or-later
Url:		https://github.com/fermitools/shell-timeout

# source archive is made with `make sources` from the upstream git repo
# or pulled from the github tag
Source:		%{url}/archive/refs/tags/%{version}.tar.gz

Requires:	coreutils filesystem sed
BuildRequires:	make
%if %{with tests}
BuildRequires:	podman
%endif

Summary:	A simple set of scripts for setting shell timeout automatically
%description
These scripts automatically set shell timeout values based on user ID (UID)
or group ID (GID) membership in POSIX shells (bash/zsh) and C shells (csh/tcsh).

When a matching user logs in, their shell will automatically terminate
after a configured period of inactivity.

%prep
%setup -q

%build

%install
# these must be in /etc/profile.d to actually work
%{__install} -m 644 -D src/shell-timeout.sh  %{buildroot}%{_sysconfdir}/profile.d/shell-timeout.sh
%{__install} -m 644 -D src/shell-timeout.csh %{buildroot}%{_sysconfdir}/profile.d/shell-timeout.csh

# the scripts are hard coded to check
#   /etc/default/shell-timeout
#   /etc/default/shell-timeout.d
# variables here would be counter-productive as they don't change the code
%{__install} -m 644 -D conf/shell-timeout %{buildroot}/etc/default/shell-timeout

%check
%if %{with tests}
make test
%endif

%files
%license LICENSE
%doc README.md conf/shell-timeout
%{_sysconfdir}/profile.d/shell-timeout.sh
%{_sysconfdir}/profile.d/shell-timeout.csh
%config(noreplace) /etc/default/shell-timeout

%changelog
* Wed Dec 17 2025 Pat Riehecky <riehecky@fnal.gov> - 0.1.0-1
* Initial build
