#!/bin/bash

set -e

if [ -n "$1" ]; then
	exec "$@"
	exit 0
fi

test -n "$ARCH" || ARCH=tf1

test -z "$BF_LOG_DIR" && BF_LOG_DIR=/var/log
MODEL_ARGS="--log-dir $BF_LOG_DIR"

test -z "$BF_DEBUG" && MODEL_ARGS="$MODEL_ARGS -q -- --thread-per-pipe"

if [ -n "$P4_BUILD" ]; then
	echo "Building P4 code from $P4_BUILD"
	BUILD_ARCH=--with-tofino
	test "$ARCH" = "tf2" && BUILD_ARCH=--with-tofino2
	p4_build.sh $P4_BUILD $BUILD_ARCH
fi

if [ -n "$P4_NAME" ]; then
	echo "Starting tofino-model and bf-switchd with p4_name=$P4_NAME arch=$ARCH"

	echo "setup ports file to /tmp/ports.json"
	setup_ports.sh $ARCH /tmp/ports.json

	MODEL_ARGS="-p $P4_NAME --arch $ARCH -f /tmp/ports.json --use-pcie-veth $MODEL_ARGS"
	echo "start tofino model with args: $MODEL_ARGS"
	tmux new-sess -d -s model run_tofino_model.sh $MODEL_ARGS

	BF_ARGS="-p $P4_NAME --arch $ARCH $BF_ARGS"
	echo "starting bf_switchd with args: $BF_ARGS"
	tmux new-sess -d -s driver run_switchd.sh $BF_ARGS

	wait-tofino.sh

	if [ -n "$BF_STARTUP_BFSHELL" ]; then
		echo "Running bfshell script at $BF_STARTUP_BFSHELL"
		run_bfshell.sh -f $BF_STARTUP_BFSHELL
	fi

	if [ -n "$BF_STARTUP_BFPY" ]; then
		echo "Running bfrt_python script at $BF_STARTUP_BFPY"
		run_bfshell.sh -b $BF_STARTUP_BFPY
	fi
fi

echo "Leaving tail -f /dev/null running.."
tail -f /dev/null

