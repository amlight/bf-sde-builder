#!/bin/bash

set -e

test -n "$ARCH" || ARCH=tf1

HUGE_PAGES=$(grep HugePages_Total /proc/meminfo 2>/dev/null | awk '{print $2}')

if [ -z "$HUGE_PAGES" -o "$HUGE_PAGES" -lt 2048 ]; then
    echo "WARNING: No hugepages detected. Running bf-switch on docker requires hugepages."
    echo "Please run on the host:"
    echo "       sysctl vm.nr_hugepages=2048"
    echo "       mount -t hugetlbfs none /dev/hugepages"
    exit 1
fi

if [ -n "$P4_BUILD" ]; then
	echo "Building P4 code from $P4_BUILD"
	BUILD_ARCH=--with-tofino
	test "$ARCH" = "tf2" && BUILD_ARCH=--with-tofino2
	p4_build.sh $P4_BUILD $BUILD_ARCH
fi

if [ -n "$1" ]; then
	if [ -n "$P4_NAME" ]; then
		echo "starting supervisord"
		/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
	fi
	exec "$@"
else
	if [ -n "$P4_NAME" ]; then
		echo "starting supervisord"
		exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
	fi
fi

