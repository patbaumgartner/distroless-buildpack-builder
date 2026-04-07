# Build stack image – used during the build phase of the CNB lifecycle.
# Ubuntu 24.04 provides the full toolchain; a Jammy stage supplies ICU 70
# libraries required by Paketo buildpacks compiled against Ubuntu 22.04.

# Stage 1: ICU 70 compatibility libraries from Ubuntu 22.04
FROM ubuntu:24.04@sha256:84e77dee7d1bc93fb029a45e3c6cb9d8aa4831ccfcc7103d36e876938d28895b AS icu-compat
# hadolint ignore=DL3008
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libicu70 \
    && rm -rf /var/lib/apt/lists/* \
    && ARCH="$(uname -m)" \
    && mkdir -p /staging \
    && cp -a "/usr/lib/${ARCH}-linux-gnu"/libicu*.so.70* /staging/

# Stage 2: Main build image
FROM ubuntu:24.04@sha256:84e77dee7d1bc93fb029a45e3c6cb9d8aa4831ccfcc7103d36e876938d28895b

ARG CNB_USER_ID=1000
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

LABEL io.buildpacks.stack.id="${CNB_STACK_ID}"
LABEL io.buildpacks.base.distro.name="ubuntu"
LABEL io.buildpacks.base.distro.version="24.04"
LABEL maintainer="patbaumgartner"
LABEL org.opencontainers.image.source="https://github.com/patbaumgartner/distroless-buildpack-builder"
LABEL org.opencontainers.image.description="Build stack image for the Distroless Buildpack Builder (Ubuntu 24.04 Noble)"

# Install build-time dependencies mirroring the official Paketo build stack.
# hadolint ignore=DL3008
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    fontconfig \
    git \
    jq \
    libexpat1 \
    libffi-dev \
    libgmp-dev \
    libicu-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    libyaml-dev \
    netbase \
    openssl \
    pkg-config \
    tzdata \
    unzip \
    xz-utils \
    zip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Inject ICU 70 libs; coexist with Noble's .so.74 files.
COPY --from=icu-compat /staging/ /usr/lib/
RUN ldconfig

# Create the CNB user/group (remove default 'ubuntu' user if present).
RUN if getent passwd ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi \
    && if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi \
    && groupadd --gid "${CNB_GROUP_ID}" cnb \
    && useradd \
    --uid  "${CNB_USER_ID}" \
    --gid  cnb \
    --shell /bin/bash \
    --create-home \
    cnb

# Create CNB working directories.
RUN mkdir -p /workspace /cnb/buildpacks /platform /layers \
    && chown -R cnb:cnb /workspace /cnb /platform /layers

USER cnb

ENV CNB_STACK_ID="${CNB_STACK_ID}"
ENV CNB_USER_ID="${CNB_USER_ID}"
ENV CNB_GROUP_ID="${CNB_GROUP_ID}"
