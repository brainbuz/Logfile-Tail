#!/bin/bash

set -e
set -x

DNF=yum
BUILDDEP_PROVIDER=yum-utils
BUILDDEP=yum-builddep
if type dnf 2> /dev/null ; then
	DNF=dnf
	BUILDDEP_PROVIDER='dnf-command(builddep)'
	BUILDDEP='dnf builddep'
fi

$DNF install -y rpm-build "$BUILDDEP_PROVIDER"
$BUILDDEP -y perl-Logfile-Tail.spec
mkdir -p ~/rpmbuild/SOURCES
perl Makefile.PL
make dist
mv ../Logfile-Tail-*.tar.gz ~/rpmbuild/SOURCES
rpmbuild -bb --define "dist $( rpm --eval '%{dist}' ).localbuild" perl-Logfile-Tail.spec
$DNF install -y ~/rpmbuild/RPMS/*/perl-Logfile-Tail-*.localbuild.*.rpm
