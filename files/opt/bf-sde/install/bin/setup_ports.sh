#!/usr/bin/env bash

add_veth_pair() {
	intf0=$1
	intf1=$2
	if ! ip link show $intf0 &> /dev/null; then
	    ip link add name $intf0 type veth peer name $intf1 &> /dev/null
	fi
	ip link set dev $intf0 mtu 10240 up
	ip link set dev $intf1 mtu 10240 up

	# disable the offload of some features to avoid problems with the pipeline
	TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
	for TOE_OPTION in $TOE_OPTIONS; do
	   /sbin/ethtool --offload $intf0 "$TOE_OPTION" off &> /dev/null || true
	   /sbin/ethtool --offload $intf1 "$TOE_OPTION" off &> /dev/null || true
	done

	# do not fail if ipv6 is disabled system-wide
	sysctl net.ipv6.conf.$intf0.disable_ipv6=1 &> /dev/null || true
	sysctl net.ipv6.conf.$intf1.disable_ipv6=1 &> /dev/null || true

	echo $(date -u +%F,%T) "Added: $intf0,$intf1"
}

port_json() {
	local DEV_ID=$1
	local PORT=$2
	local DESC=$3
	local SEP=$4

	echo '    {'
	echo '        "_comment": "Map '$DESC' to veth'$PORT'",'
	echo '        "device_port": '$DEV_ID','
	echo '        "veth1": '$(($PORT+1000))','
	echo '        "veth2": '$PORT
        echo '    }'$SEP
}

test -n "$1" && ARCH=$1
PORTS_FILE=/tmp/ports.json
test -n "$2" && PORTS_FILE=$2

if [ "$ARCH" = "tf1" ]; then
	PORTS=64
	LANES=4
	# tf1 simulates 2 pipes by default, so ports 1-8 and 9-16 will be
	# associatd with pipe 1 and 17-24, 25-32 will go on pipe 2
	#     ports >>  1-8   9-16   17-24   25-32     33-40     41-48     49-56      57-64
	PORT_ID_LAYOUT="0     32     128     160       256       288       384        420"
elif [ "$ARCH" = "tf2" ]; then
	PORTS=32
	LANES=8
	# tf2 simulates 4 pipes by default, so ports 1-8 goes to pipe 1,
	# 9-16 goes to pipe 2, 17-24 goes to pipe 3, 25-32 will go on pipe 4
	#     ports >>  1-8   9-16   17-24   25-32
	PORT_ID_LAYOUT="8     136    264     392"
else
	echo "Invalid arch! allowed: tf1 or tf2"
	exit 1
fi

# this script should run before run_tofino_model.sh, which should run before run_switchd.sh
# thus we force any existing exec of bf_switchd to finish
pkill -9 bf_switchd 2>/dev/null || true

# front panel ports
for I in $(seq 1 $PORTS); do
	for L in $(seq 0 $LANES); do
		intf0="veth$(($I + $L*100))"
		intf1="veth$((1000 + $I + $L*100))"
		add_veth_pair $intf0 $intf1
	done
done

if [ "$ARCH" = "tf1" ]; then
	add_veth_pair veth320 veth1320  # port 320 - PCIe CPU
	add_veth_pair veth65  veth1065  # port 64 (65/0) - Eth CPU
	add_veth_pair veth165 veth1165  # port 65 (65/1) - Eth CPU
	add_veth_pair veth265 veth1265  # port 66 (65/2) - Eth CPU
	add_veth_pair veth365 veth1365  # port 67 (65/3) - Eth CPU
else
	add_veth_pair veth0   veth1000  # port 0 - PCIe CPU
	add_veth_pair veth33  veth1033  # port 2 (33/0) - Eth CPU
	add_veth_pair veth133 veth1133  # port 3 (33/1) - Eth CPU
	add_veth_pair veth233 veth1233  # port 4 (33/2) - Eth CPU
	add_veth_pair veth333 veth1333  # port 5 (33/3) - Eth CPU
fi

# create ports file

echo '{' > $PORTS_FILE
echo '  "PortToVeth": [' >> $PORTS_FILE
PORT=0
for FIRST_PORT_ID in $PORT_ID_LAYOUT; do
	for I in $(seq 0 7); do
		PORT=$(($PORT + 1))
		for L in $(seq 0 $(($LANES-1))); do
			DEV_ID=$(($FIRST_PORT_ID + $I*$LANES + $L))
			OF_PORT=$(($PORT + $L*100))
			#VETH=veth$OF_PORT
			#echo "$PORT/$L -> port-id $DEV_ID -> $VETH"
			port_json $DEV_ID $OF_PORT "front-panel port $PORT/$L" , >> $PORTS_FILE
		done
	done
done

if [ "$ARCH" = "tf1" ]; then
	port_json 320 320 "PCIe CPU port" , >> $PORTS_FILE
	port_json 64  65  "Ethernet CPU port #1" , >> $PORTS_FILE
	port_json 65  165 "Ethernet CPU port #2" , >> $PORTS_FILE
	port_json 66  265 "Ethernet CPU port #3" , >> $PORTS_FILE
	port_json 67  365 "Ethernet CPU port #4" >> $PORTS_FILE
else
	port_json 0 0   "PCIe CPU port" , >> $PORTS_FILE
	port_json 2 33  "Ethernet CPU port #1" , >> $PORTS_FILE
	port_json 3 133 "Ethernet CPU port #2" , >> $PORTS_FILE
	port_json 4 233 "Ethernet CPU port #3" , >> $PORTS_FILE
	port_json 5 333 "Ethernet CPU port #4" >> $PORTS_FILE
fi
echo '  ]' >> $PORTS_FILE
echo '}' >> $PORTS_FILE

echo ports saved to $PORTS_FILE
