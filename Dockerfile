# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.15
ARG MESA_VERSION=25.0.7

# Plex Transcoder currently embeds musl 1.2.2. Alpine 3.15 uses the same
# musl ABI, while Mesa 25 provides support for recent AMD GPUs (gfx11/gfx12).
FROM alpine:${ALPINE_VERSION} AS mesa-builder
ARG MESA_VERSION

RUN apk add --no-cache \
      build-base bison flex curl tar xz \
      python3 py3-pip py3-mako py3-packaging \
      meson ninja pkgconf patchelf pax-utils \
      expat-dev libdrm-dev elfutils-dev libffi-dev \
      libva-dev zlib-dev zstd-dev && \
    curl -fsSLo /tmp/mesa.tar.xz \
      "https://archive.mesa3d.org/mesa-${MESA_VERSION}.tar.xz" && \
    mkdir /tmp/mesa && \
    tar -xJf /tmp/mesa.tar.xz -C /tmp/mesa --strip-components=1 && \
    meson setup /tmp/mesa/build /tmp/mesa \
      --prefix=/usr/local \
      --buildtype=release \
      -Dplatforms=[] \
      -Dgallium-drivers=radeonsi \
      -Dvulkan-drivers=[] \
      -Dllvm=disabled \
      -Dshared-llvm=disabled \
      -Dgallium-va=enabled \
      -Dvideo-codecs=all \
      -Dglx=disabled \
      -Degl=disabled \
      -Dgbm=disabled \
      -Dgles1=disabled \
      -Dgles2=disabled \
      -Dopengl=false \
      -Dbuild-tests=false && \
    ninja -C /tmp/mesa/build install

RUN set -eux; \
    driver=/usr/local/lib/dri/radeonsi_drv_video.so; \
    test -f "$driver"; \
    mkdir -p /opt/vaapi/dri; \
    cp -aL "$driver" /opt/vaapi/dri/; \
    lddtree -l "$driver" | while read -r library; do \
      case "$library" in \
        */ld-musl-*|*/libc.musl-*|"") continue ;; \
      esac; \
      cp -aL "$library" /opt/vaapi/; \
    done; \
    patchelf --set-rpath /opt/vaapi /opt/vaapi/dri/radeonsi_drv_video.so; \
    for library in /opt/vaapi/*.so*; do \
      patchelf --set-rpath /opt/vaapi "$library" 2>/dev/null || true; \
    done

FROM lscr.io/linuxserver/plex:latest

LABEL org.opencontainers.image.source="https://github.com/maxhugit/plex-amd-vaapi" \
      org.opencontainers.image.description="LinuxServer Plex with a musl-compatible AMD VAAPI driver" \
      org.opencontainers.image.licenses="MIT"

COPY --from=mesa-builder /opt/vaapi /opt/vaapi

ENV LIBVA_DRIVERS_PATH=/opt/vaapi/dri \
    LIBVA_DRIVER_NAME=radeonsi
