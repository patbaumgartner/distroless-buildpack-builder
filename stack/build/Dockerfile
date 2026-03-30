# ---------------------------------------------------------------------------
# Build stack image – used during the *build* phase of the CNB lifecycle.
# Based on Ubuntu 24.04 Noble to provide a full toolchain for compiling apps.
# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG CNB_USER_ID=1000
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

LABEL io.buildpacks.stack.id="${CNB_STACK_ID}"
LABEL io.buildpacks.base.distro.name="ubuntu"
LABEL io.buildpacks.base.distro.version="24.04"
LABEL maintainer="patbaumgartner"
LABEL org.opencontainers.image.source="https://github.com/patbaumgartner/distroless-buildpack-builder"
LABEL org.opencontainers.image.description="Build stack image for the Distroless Buildpack Builder (Ubuntu 24.04 Noble)"

# Install build-time dependencies required by common Paketo buildpacks.
# DEBIAN_FRONTEND=noninteractive prevents interactive prompts during apt-get.
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       wget \
       git \
       jq \
       build-essential \
       libssl-dev \
       zlib1g-dev \
       libffi-dev \
       unzip \
       zip \
    && rm -rf /var/lib/apt/lists/*

# Create the CNB user/group.
# Only remove the default 'ubuntu' user/group if they exist at UID/GID 1000
# so we can safely claim those IDs for the CNB user. The conditional check
# avoids failures when the ubuntu:24.04 base image ships without this user.
RUN if getent passwd ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi \
    && if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi \
    && groupadd --gid "${CNB_GROUP_ID}" cnb \
    && useradd \
       --uid  "${CNB_USER_ID}" \
       --gid  cnb \
       --shell /bin/bash \
       --create-home \
       cnb

# Create CNB working directories and hand them over to the cnb user.
RUN mkdir -p /workspace /cnb/buildpacks /platform /layers \
    && chown -R cnb:cnb /workspace /cnb /platform /layers

USER cnb

ENV CNB_STACK_ID="${CNB_STACK_ID}"
ENV CNB_USER_ID="${CNB_USER_ID}"
ENV CNB_GROUP_ID="${CNB_GROUP_ID}"
