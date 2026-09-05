FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    cmake \
    curl \
    git \
    libglu1-mesa \
    ninja-build \
    pkg-config \
    sudo \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN id -u ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu \
    && usermod -aG sudo ubuntu \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu

ENV FLUTTER_HOME=/opt/flutter
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    && git config --global --add safe.directory "$FLUTTER_HOME" \
    && chmod -R a+rX "$FLUTTER_HOME"

ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
RUN flutter config --no-analytics \
    && flutter precache --linux

USER ubuntu
WORKDIR /home/ubuntu
