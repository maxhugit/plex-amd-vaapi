# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.15
ARG MESA_VERSION=25.0.7
ARG LIBDRM_VERSION=2.4.124

# Plex Transcoder currently embeds musl 1.2.2. Alpine 3.15 uses the same
# musl ABI, while Mesa 25 provides support for recent AMD GPUs (gfx11/gfx12).
FROM alpine:${ALPINE_VERSION} AS mesa-builder
ARG MESA_VERSION
ARG LIBDRM_VERSION

RUN apk add --no-cache \
      build-base bison flex curl tar xz \
      python3 py3-pip py3-mako py3-packaging py3-yaml \
      ninja pkgconf patchelf pax-utils \
      expat-dev libdrm-dev elfutils-dev libffi-dev \
      libva-dev zlib-dev zstd-dev && \
    pip3 install --no-cache-dir 'meson>=1.3,<2' && \
    curl -fsSLo /tmp/libdrm.tar.xz \
      "https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VERSION}.tar.xz" && \
    mkdir /tmp/libdrm && \
    tar -xJf /tmp/libdrm.tar.xz -C /tmp/libdrm --strip-components=1 && \
    meson setup /tmp/libdrm/build /tmp/libdrm \
      --prefix=/usr/local \
      --buildtype=release \
      -Dintel=disabled \
      -Dradeon=disabled \
      -Damdgpu=enabled \
      -Dnouveau=disabled \
      -Dvmwgfx=disabled \
      -Dtests=false \
      -Dudev=false \
      -Dvalgrind=disabled \
      -Dman-pages=disabled && \
    ninja -C /tmp/libdrm/build install && \
    curl -fsSLo /tmp/mesa.tar.xz \
      "https://archive.mesa3d.org/mesa-${MESA_VERSION}.tar.xz" && \
    mkdir /tmp/mesa && \
    tar -xJf /tmp/mesa.tar.xz -C /tmp/mesa --strip-components=1 && \
    sed -i '/util_qsort_r(void/i #undef HAVE_GNU_QSORT_R' /tmp/mesa/src/util/u_qsort.h && \
    sed -i '/util_qsort_r(void/i #undef HAVE_BSD_QSORT_R' /tmp/mesa/src/util/u_qsort.h && \
    sed -i '/util_qsort_r(void/i #undef HAVE_QSORT_S' /tmp/mesa/src/util/u_qsort.h && \
    sed -i '/util_qsort_r(void/i #define HAVE_QSORT_S 0' /tmp/mesa/src/util/u_qsort.h && \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig meson setup /tmp/mesa/build /tmp/mesa \
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
    for library in /usr/lib/*.so* /lib/*.so* /usr/local/lib/*.so*; do \
      test -e "$library" || continue; \
      case "$library" in */ld-musl-*|*/libc.musl-*) continue ;; esac; \
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
COPY --chmod=755 root/custom-cont-init.d/10-plex-amd-vaapi /custom-cont-init.d/10-plex-amd-vaapi

ENV LIBVA_DRIVERS_PATH=/opt/vaapi/dri \
    LIBVA_DRIVER_NAME=radeonsi \
    XDG_CACHE_HOME=/config/.cache
