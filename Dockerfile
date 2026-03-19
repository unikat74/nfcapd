FROM debian:12-slim

ARG NFDUMP_VERSION=1.7.7

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    tzdata \
    tini \
    findutils \
    coreutils \
    procps \
    flex \
    bison \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Warsaw

WORKDIR /usr/src

RUN wget -O nfdump-${NFDUMP_VERSION}.tar.gz \
    https://codeload.github.com/phaag/nfdump/tar.gz/refs/tags/v${NFDUMP_VERSION} \
    && tar xzf nfdump-${NFDUMP_VERSION}.tar.gz \
    && SRC_DIR="$(find /usr/src -maxdepth 1 -type d -name 'nfdump-*' | head -n 1)" \
    && cd "${SRC_DIR}" \
    && [ -x ./autogen.sh ] && ./autogen.sh || true \
    && ./configure --enable-nsel --enable-nel \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /usr/src/nfdump*

RUN mkdir -p /flows

COPY entrypoint.sh /entrypoint.sh
COPY cleanup.sh /cleanup.sh
RUN chmod +x /entrypoint.sh /cleanup.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
