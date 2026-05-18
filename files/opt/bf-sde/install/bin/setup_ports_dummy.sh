#!/usr/bin/env bash

add_port() {
	intf0=$1
	#intf1=$2
	if ! ip link show $intf0 &> /dev/null; then
            ip link add name $intf0 type dummy &> /dev/null
	    ip link set dev $intf0 arp on &> /dev/null
	    #ip link add name $intf0 type veth peer name $intf1 &> /dev/null
	fi
	ip link set dev $intf0 mtu 10240 up
	#ip link set dev $intf1 mtu 10240 up

	# disable the offload of some features to avoid problems with the pipeline
	TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
	for TOE_OPTION in $TOE_OPTIONS; do
	   /sbin/ethtool --offload $intf0 "$TOE_OPTION" off &> /dev/null || true
	   #/sbin/ethtool --offload $intf1 "$TOE_OPTION" off &> /dev/null || true
	done

	# do not fail if ipv6 is disabled system-wide
	sysctl net.ipv6.conf.$intf0.disable_ipv6=1 &> /dev/null || true
	#sysctl net.ipv6.conf.$intf1.disable_ipv6=1 &> /dev/null || true

	echo "Added: $intf0"
	#echo "Added: $intf0,$intf1"
}

port_json() {
	local DEV_ID=$1
	local PORT=$2
	local DESC=$3
	local SEP=$4

	echo '    {'
	echo '        "_comment": "Map '$DESC' to veth'$PORT'",'
	echo '        "device_port": '$DEV_ID','
	echo '        "if": "'$PORT'"'
	#echo '        "veth1": '$(($PORT+1000))','
	#echo '        "veth2": '$PORT
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

# front panel ports
for I in $(seq 1 $PORTS); do
	for L in $(seq 0 $LANES); do
		#intf0="veth$(($I + $L*100))"
		#intf1="veth$((1000 + $I + $L*100))"
		#add_veth_pair $intf0 $intf1
		port="port_${I}_${L}"
		add_port $port
	done
done

if [ "$ARCH" = "tf1" ]; then
	add_port cpu_pcie   # port 320
	add_port cpu_eth_1  # port 64
	add_port cpu_eth_2  # port 65
	add_port cpu_eth_3  # port 66
	add_port cpu_eth_4  # port 67
else
	add_port cpu_pcie   # port 0
	add_port cpu_eth_1  # port 2
	add_port cpu_eth_2  # port 3
	add_port cpu_eth_3  # port 4
	add_port cpu_eth_4  # port 5
fi

# create ports file

echo '{' > $PORTS_FILE
echo '  "PortToIf": [' >> $PORTS_FILE
#echo '  "PortToVeth": [' >> $PORTS_FILE
PORT=0
for FIRST_PORT_ID in $PORT_ID_LAYOUT; do
	for I in $(seq 0 7); do
		PORT=$(($PORT + 1))
		for L in $(seq 0 $(($LANES-1))); do
			DEV_ID=$(($FIRST_PORT_ID + $I*$LANES + $L))
			#OF_PORT=$(($PORT + $L*100))
			#VETH=veth$OF_PORT
			#echo "$PORT/$L -> port-id $DEV_ID -> $VETH"
			#port_json $DEV_ID $OF_PORT "front-panel port $PORT/$L" , >> $PORTS_FILE
			port="port_${PORT}_${L}"
			port_json $DEV_ID $port "front-panel port $PORT/$L" , >> $PORTS_FILE
		done
	done
done

if [ "$ARCH" = "tf1" ]; then
	port_json 320 cpu_pcie  "PCIe CPU port" , >> $PORTS_FILE
	port_json 64  cpu_eth_1 "Ethernet CPU port #1" , >> $PORTS_FILE
	port_json 65  cpu_eth_2 "Ethernet CPU port #2" , >> $PORTS_FILE
	port_json 66  cpu_eth_3 "Ethernet CPU port #3" , >> $PORTS_FILE
	port_json 67  cpu_eth_4 "Ethernet CPU port #4" >> $PORTS_FILE
else
	port_json 0 cpu_pcie  "PCIe CPU port" , >> $PORTS_FILE
	port_json 2 cpu_eth_1 "Ethernet CPU port #1" , >> $PORTS_FILE
	port_json 3 cpu_eth_2 "Ethernet CPU port #2" , >> $PORTS_FILE
	port_json 4 cpu_eth_3 "Ethernet CPU port #3" , >> $PORTS_FILE
	port_json 5 cpu_eth_4 "Ethernet CPU port #4" >> $PORTS_FILE
fi
echo '  ]' >> $PORTS_FILE
echo '}' >> $PORTS_FILE

echo ports saved to $PORTS_FILE
