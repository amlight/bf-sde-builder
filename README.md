# Intel P4Studio SDE builder

This repo contains instructions on how to build and use Intel's P4Studio SDE (also known as bf-sde) for the virtual/emulated environment (tofino-model) or real hardware.

## 1. Building Intel P4Studio SDE

We will build three versions of Intel SDE:
1) open-p4studio (latest bf-sde released by Intel) with tofino-model for testing and development environment
2) bf-sde 9.13.4 with BSP for Tofino 1 (real hardware)
3) bf-sde 9.13.4 with BSP for Tofino 2 (real hardware)

Pre-requirements for the building environment:
- Debian 11 installation with Kernel 5.10.0-32-amd64
- At least 30G of disk, 8GB of RAM and 4-core CPU
- For the real hardware build you will need bf-sde-9.13.4.tgz and bf-reference-bsp-9.13.4.tgz (BSP - Board Support Package, required to interface with specific Tofino-based hardware platforms -- bf-reference-bsp-9.13.4.tgz is the reference BSP provided by Intel and works well with EdgeCore switches; for other hardware vendors like UfiSpace, Stordis, etc we might need their BSP)


### 1.1. Build open-p4studio with tofino-model using Docker

This is the recommeneded approach for experimenting with BF-SDE and Tofino Model.

```
git clone https://github.com/amlight/bf-sde-builder
cd bf-sde-builder
docker build -t amlight/bf-sde:9.13.4 .
```

Please refer to the "2. Using bf-sde with tofino-model" for how to use it.

### 1.2. Build open-p4studio with tofino-model manually

```
apt-get update
apt-get install git sudo python3 python3-pip build-essential cmake ca-certificates libssl-dev
git clone https://github.com/p4lang/open-p4studio /opt/bf-sde
cd /opt/bf-sde
sed -i s/ftp.debian.org/archive.debian.org/g p4studio/dependencies/p4i.dependencies.yaml
mkdir -p /lib/modules/$(uname -r)/build
./p4studio/p4studio profile apply --jobs $(nproc) ./p4studio/profiles/docker.yaml

mkdir -p bf-sde-dev-9.13.4/opt/bf-sde
cp -r install cmake p4studio bf-sde-dev-9.13.4/opt/bf-sde/
find bf-sde-dev-9.13.4/opt/bf-sde/install/lib -name "*.so*" -exec strip --strip-unneeded {} +
find bf-sde-dev-9.13.4/opt/bf-sde/install/bin -type f -exec strip --strip-unneeded {} +
cp run_*.sh bf-sde-dev-9.13.4/opt/bf-sde/install/bin/
git clone https://github.com/amlight/bf-sde-builder /root/bf-sde-builder
cp -r /root/bf-sde-builder/bf-sde-dev/* bf-sde-dev-9.13.4/
dpkg-deb --build bf-sde-dev-9.13.4
```

Copy the resulting `bf-sde-dev-9.13.4.deb` to install where you want to run your development environment (which must be a Debian11 based).

### 1.3. Build bf-sde 9.13.4 for Tofino1

TODO

### 1.4. Build bf-sde 9.13.4 for Tofino2

TODO

## 2. Using bf-sde with tofino-model

Example using the new procedure:

TODO

Using the old procedure (this is outdated):

To run bf-sde with tofino-model using Docker (after building the docker image), you can run the following command:

```
docker run -it --rm --privileged amlight/bf-sde:9.13.4 bash
```

After the command above, you will have a Bash interactive shell where you can build your P4 code, run your tests, etc. For example, the sequence below will ilustrate how to build a very simple P4 example and test it:

```
curl -LO https://raw.githubusercontent.com/italovalcy/bf-p4-examples/refs/heads/main/tna_basic/tna_basic.p4
p4_build.sh tna_basic.p4
setup_ports.sh tf1 /tmp/ports.json
tmux new-sess -d -s model run_tofino_model.sh -p tna_basic --arch tf1 -f /tmp/ports.json --log-dir /var/log --use-pcie-veth
tmux new-sess -d -s driver run_switchd.sh -p tna_basic --arch tf1
wait-tofino.sh

# At this point, the switch should be ready to forward traffic. Let's test it:

TODO: get from history

   12  ip netns add h1
   13  ip netns add h2
   14  ip link set veth1 netns h1
   15  ip link set veth2 netns h1
   16  tail /var/log/model_20260401_205622.log
   17  ip netns exec h1 ip link set up veth1
   18  ip netns exec h2 ip link set up veth2
   19  ip netns exec h1 ip link set veth2 netns 0
   20  ip netns exec h1 ip link set veth2 netns 1
   21  ip link set veth2 netns h2
   22  ip netns exec h2 ip link set up veth2
   23  tail /var/log/model_20260401_205622.log
   24  grep PORT /var/log/model_20260401_205622.log
   25  ip netns exec h1 ip addr add 10.0.0.1/24 dev veth1
   26  ip netns exec h2 ip addr add 10.0.0.2/24 dev veth2
   27  bfshell
   28  ip netns exec h1 ping -c4 10.0.0.2
   29  ip netns exec h1 ad show
   30  ip netns exec h1 ip a s
   31  tail /var/log/model_20260401_205622.log
   32  ip netns exec h1 ping -c4 10.0.0.2 -s 1400
   33  grep "Tx Pkt to port" /var/log/model_20260401_205622.log
   34  grep "Tx Pkt to port" /var/log/model_*.log

```


