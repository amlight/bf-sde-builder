# Stage 1: build bf-sde
FROM debian:11 as builder

RUN apt-get update && apt-get install -y \
    git sudo python3 python3-pip build-essential cmake ca-certificates libssl-dev \
    && apt-get clean

RUN git clone https://github.com/p4lang/open-p4studio /opt/bf-sde \
 && cd /opt/bf-sde \
 && sed -i s/ftp.debian.org/archive.debian.org/g p4studio/dependencies/p4i.dependencies.yaml \
 && mkdir -p /lib/modules/$(uname -r)/build \
 && ./p4studio/p4studio profile apply --jobs $(nproc) ./p4studio/profiles/docker.yaml

RUN cd /opt/bf-sde \
 && find install/lib -name "*.so*" -exec strip --strip-unneeded {} + || true \
 && find install/bin -type f -exec strip --strip-unneeded {} + || true \
 && mv run_*.sh install/bin/

# Stage 2: actual runtime environment
FROM debian:11

COPY --from=builder /opt/bf-sde/install  /opt/bf-sde/install
COPY --from=builder /opt/bf-sde/cmake    /opt/bf-sde/cmake
COPY --from=builder /opt/bf-sde/p4studio /opt/bf-sde/p4studio

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ cmake make tmux socat lsof netcat tini tcpdump vim-tiny \
    ethtool iputils-ping iproute2 procps curl jq sudo ca-certificates \
    libedit2 libexpat1 python3-dev python3-thrift python3-scapy \
    python3-cryptography libcurl3-gnutls libusb-1.0-0 libjudydebian1 \
 && apt-get clean

RUN ls /opt/bf-sde && ln -s /opt/bf-sde/install/bin/p4c /opt/bf-sde/install/bin/bf-p4c

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY tools/* /opt/bf-sde/install/bin/

ENV SDE=/opt/bf-sde
ENV SDE_INSTALL=$SDE/install
ENV PATH=$SDE_INSTALL/bin:$PATH

ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]
