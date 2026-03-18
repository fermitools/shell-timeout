# test suite runs a bunch of podman, can't do that within the buildroot of koji or mock
%bcond tests 0

Name:		shell-timeout
Version:	0.3.0
Release:	%autorelease
BuildArch:	noarch

License:	GPL-3.0-or-later
Url:		https://github.com/fermitools/shell-timeout
Source:		%{url}/archive/%{version}/%{name}-%{version}.tar.gz

Requires:	coreutils filesystem sed
BuildRequires:  make bash grep shellcheck
BuildRequires:  (rubygem-asciidoctor or asciidoc)
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
%autosetup

%build
make man

%install
# these must be in /etc/profile.d to actually work
install -p -m 644 -D src/shell-timeout.sh  %{buildroot}%{_sysconfdir}/profile.d/shell-timeout.sh
install -p -m 644 -D src/shell-timeout.csh %{buildroot}%{_sysconfdir}/profile.d/shell-timeout.csh

mkdir -p %{buildroot}%{_mandir}/man5/
cp -pa man/shell-timeout.conf.5 %{buildroot}%{_mandir}/man5/


# the scripts are hard coded to check
#   /etc/default/shell-timeout
#   /etc/default/shell-timeout.d
# variables here would be counter-productive as they don't change the code
install -p -m 644 -D conf/shell-timeout %{buildroot}/etc/default/shell-timeout
mkdir %{buildroot}/etc/default/shell-timeout.d

%check
%if %{with tests}
make test
%else
make test-shellcheck
%endif

%files
%license LICENSE
%doc docs/README.md
%doc %{_mandir}/man5/*
%{_sysconfdir}/profile.d/shell-timeout.sh
%{_sysconfdir}/profile.d/shell-timeout.csh
%config(noreplace) /etc/default/shell-timeout
%dir /etc/default/shell-timeout.d

%changelog
%autochangelog
