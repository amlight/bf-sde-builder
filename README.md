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

### 1.2. Build open-p4studio with tofino-model

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

## Using bf-sde with tofino-model

To run bf-sde with tofino-model using Docker (after building the docker image), you can run the following command:

```
docker run -it --rm amlight/bf-sde:9.13.4 bash
```

After the command above, you will have a Bash interactive shell where you can build your P4 code, run your tests, etc. For example, the sequence below will ilustrate how to build a very simple P4 example and test it:

```

```
