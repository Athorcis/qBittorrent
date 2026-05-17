# syntax=docker/dockerfile:1
# qBittorrent-nox (Web UI uniquement) — Debian slim, build multi-stage.
# Bookworm : Qt < 6.6 → trixie-slim (Debian testing, toujours minimal).

ARG DEBIAN_IMAGE=debian:trixie-slim
ARG BOOST_VERSION=1.91.0
ARG LIBTORRENT_TAG=v2.0.12

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
FROM ${DEBIAN_IMAGE} AS builder

ARG BOOST_VERSION
ARG LIBTORRENT_TAG

ENV DEBIAN_FRONTEND=noninteractive \
    CFLAGS="-pipe -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3" \
    CXXFLAGS="-pipe -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3" \
    LDFLAGS="-Wl,-O1,--as-needed"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        dpkg-dev \
        git \
        libssl-dev \
        ninja-build \
        pkg-config \
        qt6-base-dev \
        qt6-base-private-dev \
        qt6-tools-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN BOOST_MAJOR="${BOOST_VERSION%%.*}" \
    && BOOST_MINOR_PATCH="${BOOST_VERSION#*.}" \
    && BOOST_MINOR="${BOOST_MINOR_PATCH%%.*}" \
    && BOOST_PATCH="${BOOST_MINOR_PATCH#*.}" \
    && curl -fsSL -o /tmp/boost.tar.gz \
        "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_MAJOR}_${BOOST_MINOR}_${BOOST_PATCH}.tar.gz" \
    && tar -xf /tmp/boost.tar.gz -C /tmp \
    && mv /tmp/boost_* /boost \
    && cd /boost \
    && ./bootstrap.sh \
    && ./b2 stage --stagedir=./ --with-headers \
    && rm -f /tmp/boost.tar.gz

RUN git clone \
        --branch "${LIBTORRENT_TAG}" \
        --depth 1 \
        --recurse-submodules \
        https://github.com/arvidn/libtorrent.git /src/libtorrent \
    && cmake -S /src/libtorrent -B /src/libtorrent/build -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DBOOST_ROOT=/boost/lib/cmake \
        -Ddeprecated-functions=OFF \
    && cmake --build /src/libtorrent/build -j"$(nproc)" \
    && cmake --install /src/libtorrent/build

WORKDIR /src/qBittorrent
COPY . .

RUN cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DBOOST_ROOT=/boost/lib/cmake \
        -DGUI=OFF \
        -DWEBUI_LOCK_SETTINGS=ON \
        -DSTACKTRACE=OFF \
        -DTESTING=OFF \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    && strip /usr/bin/qbittorrent-nox

# Liste des paquets .deb runtime + plugins Qt utiles (SQLite, TLS)
RUN set -eux; \
    ldd /usr/bin/qbittorrent-nox \
        | awk '/=> \// {print $3} /^\// {print $1}' \
        | xargs -r readlink -f \
        | xargs -r dpkg -S 2>/dev/null \
        | cut -d: -f1 \
        | sort -u > /runtime-apt-packages.txt; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        $(cat /runtime-apt-packages.txt); \
  ARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"; \
  QT_PLUGINS="/usr/lib/${ARCH}/qt6/plugins"; \
  mkdir -p "/opt/qt6-plugins"; \
  for sub in sqldrivers tls; do \
    if [ -d "${QT_PLUGINS}/${sub}" ]; then \
      mkdir -p "/opt/qt6-plugins/${sub}"; \
      cp -a "${QT_PLUGINS}/${sub}/." "/opt/qt6-plugins/${sub}/"; \
    fi; \
  done; \
  ldd /usr/bin/qbittorrent-nox | grep -q 'not found' && exit 1 || true; \
  rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
FROM ${DEBIAN_IMAGE} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gosu \
        tini \
        tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 qbtuser \
    && useradd --uid 1000 --gid 1000 --no-create-home --shell /usr/sbin/nologin qbtuser

COPY --from=builder /runtime-apt-packages.txt /tmp/runtime-apt-packages.txt
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        $(cat /tmp/runtime-apt-packages.txt) \
    && rm -f /tmp/runtime-apt-packages.txt \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox
COPY --from=builder /opt/qt6-plugins /usr/lib/qt6/plugins

ENV QT_PLUGIN_PATH=/usr/lib/qt6/plugins

COPY docker/debian-nox/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/config", "/downloads"]
EXPOSE 8080 6881/tcp 6881/udp

ENV QBT_LEGAL_NOTICE=confirm \
    UMASK=002

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/entrypoint.sh"]
