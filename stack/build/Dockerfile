# ---------------------------------------------------------------------------
# Build stack image – used during the *build* phase of the CNB lifecycle.
# Based on Ubuntu 22.04 Jammy to provide a full toolchain for compiling apps.
# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG CNB_USER_ID=1000
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

LABEL io.buildpacks.stack.id="${CNB_STACK_ID}"
LABEL io.buildpacks.base.distro.name="ubuntu"
LABEL io.buildpacks.base.distro.version="22.04"
LABEL maintainer="patbaumgartner"
LABEL org.opencontainers.image.source="https://github.com/patbaumgartner/distroless-buildpack-builder"
LABEL org.opencontainers.image.description="Build stack image for the Distroless Buildpack Builder (Ubuntu 22.04 Jammy)"

# Install build-time dependencies required by common Paketo buildpacks.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
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
RUN groupadd --gid "${CNB_GROUP_ID}" cnb \
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
