FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb xdotool imagemagick x11-utils libsdl2-2.0-0 curl xz-utils ca-certificates \
    libgl1 libglib2.0-0 fonts-noto-core && rm -rf /var/lib/apt/lists/*
ARG KOREADER_VERSION=v2026.07.1
ARG KOREADER_ARCH=arm64
RUN curl -fsSL -o /tmp/k.tar.xz https://github.com/koreader/koreader/releases/download/${KOREADER_VERSION}/koreader-linux-${KOREADER_ARCH}-${KOREADER_VERSION}.tar.xz \
    && tar -xJf /tmp/k.tar.xz -C /opt && rm /tmp/k.tar.xz
WORKDIR /opt/koreader
