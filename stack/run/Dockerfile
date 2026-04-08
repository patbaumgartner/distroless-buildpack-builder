# Run stack image – used as the runtime base for built application images.
#
# Stage 1 (icu-compat):   ICU 70 libs from Ubuntu 22.04 for Paketo compatibility.
# Stage 2 (ubuntu-setup): CNB user/group + staged runtime libraries.
# Stage 3 (final):        Google Distroless base with injected user and libs.

# Stage 1: ICU 70 compatibility libraries from Ubuntu 22.04
# Dependabot: do NOT bump this past 22.04 — libicu70 is only available in Jammy.
FROM ubuntu:22.10@sha256:e322f4808315c387868a9135beeb11435b5b83130a8599fd7d0014452c34f489 AS icu-compat
# hadolint ignore=DL3008
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libicu70 \
    && rm -rf /var/lib/apt/lists/* \
    && ARCH="$(uname -m)" \
    && mkdir -p /staging \
    && cp -a "/usr/lib/${ARCH}-linux-gnu"/libicu*.so.70* /staging/

# Stage 2: Ubuntu setup (user/group + runtime libraries)
FROM ubuntu:24.04@sha256:84e77dee7d1bc93fb029a45e3c6cb9d8aa4831ccfcc7103d36e876938d28895b AS ubuntu-setup

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000

# Remove default 'ubuntu' user if present so we can claim GID 1000 for CNB.
# Stage runtime libraries under /staging for selective copy into distroless.
# hadolint ignore=DL3008
RUN if getent passwd ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi \
    && if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi \
    && groupadd --gid "${CNB_GROUP_ID}" cnb \
    && useradd \
    --uid  "${CNB_USER_ID}" \
    --gid  cnb \
    --no-create-home \
    cnb \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libargon2-1 \
    libcrypt1 \
    libcurl4t64 \
    libexpat1 \
    libffi8ubuntu1 \
    libgmp10 \
    libonig5 \
    libreadline8t64 \
    libsodium23 \
    libsqlite3-0 \
    libxml2 \
    libyaml-0-2 \
    netbase \
    openssl \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && ARCH="$(uname -m)" \
    && LIBDIR="${ARCH}-linux-gnu" \
    && mkdir -p "/staging/usr/lib/${LIBDIR}" "/staging/lib/${LIBDIR}" \
    && cp -a "/usr/lib/${LIBDIR}/"*.so* "/staging/usr/lib/${LIBDIR}/" \
    && cp -a "/lib/${LIBDIR}"/libssl*    "/staging/lib/${LIBDIR}/" \
    && cp -a "/lib/${LIBDIR}"/libcrypto* "/staging/lib/${LIBDIR}/"


# Stage 3: Final distroless runtime – inject user, libs, and certs into the minimal base
FROM gcr.io/distroless/cc:nonroot@sha256:9c4fe2381c2e6d53c4cfdefeff6edbd2a67ec7713e2c3ca6653806cbdbf27a1e

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

COPY --from=ubuntu-setup /etc/passwd /etc/passwd
COPY --from=ubuntu-setup /etc/group  /etc/group

# Runtime libraries (arch-specific path preserved from staging)
COPY --from=ubuntu-setup /staging/usr/lib/ /usr/lib/
COPY --from=ubuntu-setup /staging/lib/ /lib/

# ICU 70 compatibility libraries
COPY --from=icu-compat /staging/ /usr/lib/

# Timezone data, network configuration, and TLS certificates
COPY --from=ubuntu-setup /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=ubuntu-setup /etc/services /etc/services
COPY --from=ubuntu-setup /etc/protocols /etc/protocols
COPY --from=ubuntu-setup /etc/ssl/certs /etc/ssl/certs

LABEL io.buildpacks.stack.id="${CNB_STACK_ID}"
LABEL io.buildpacks.base.distro.name="distroless"
LABEL io.buildpacks.base.distro.version="cc"
LABEL maintainer="patbaumgartner"
LABEL org.opencontainers.image.source="https://github.com/patbaumgartner/distroless-buildpack-builder"
LABEL org.opencontainers.image.description="Run stack image for the Distroless Buildpack Builder (Google Distroless cc)"

USER ${CNB_USER_ID}:${CNB_GROUP_ID}
