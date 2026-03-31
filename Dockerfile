# Stage 1: build bf-sde
FROM debian:11 as builder

RUN apt-get update && apt-get install -y \
    git sudo python3 python3-pip build-essential cmake ca-certificates libssl-dev \
    && apt-get clean

RUN git clone https://github.com/p4lang/open-p4studio \
 && cd open-p4studio \
 && sed -i s/ftp.debian.org/archive.debian.org/g p4studio/dependencies/p4i.dependencies.yaml \
 && mkdir -p /lib/modules/$(uname -r)/build \
 && ./p4studio/p4studio profile apply --jobs $(nproc) ./p4studio/profiles/docker.yaml \
 && find install/lib -name "*.so*" -exec strip --strip-unneeded {} + \
 && find install/bin -type f -exec strip --strip-unneeded {} + \
 && mkdir /opt/bf-sde && cp -r install cmake p4studio run_*.sh /opt/bf-sde/

# Stage 2: actual runtime environment
FROM debian:11

COPY --from=builder /opt/bf-sde /opt/bf-sde

RUN apt-get update && apt-get install -y --no-install-recommends \
 && g++ cmake make python3-dev tmux python3-thrift tini tcpdump python3-scapy iputils-ping iproute2 procps curl jq \
 && apt-get clean \
 && ln -s /opt/bf-sde/install/bin/p4c /opt/bf-sde/install/bin/bf-p4c

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY tools/* /opt/bf-sde/install/bin/

ENV SDE=/opt/bf-sde
ENV SDE_INSTALL=$SDE/install
ENV PATH=$SDE_INSTALL:$PATH

ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]
