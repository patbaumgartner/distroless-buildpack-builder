# ---------------------------------------------------------------------------
# Run stack image – used as the *runtime* base for built application images.
#
# Multi-stage build:
#   Stage 1 (icu-compat):   Extracts ICU 70 libs from Ubuntu 22.04 for Paketo
#            buildpack binaries compiled against Jammy.
#   Stage 2 (ubuntu-setup): Creates the CNB user/group and stages runtime libs.
#   Stage 3 (final):        Google Distroless base image with the user metadata
#            and libraries injected from the earlier stages.
#
# The CNB lifecycle (v0.18+) copies the compiled application and its launcher
# binary into this image at export time, so no shell is required at runtime.
# ---------------------------------------------------------------------------

# Stage 1: ICU 70 compatibility libraries from Ubuntu 22.04 (Jammy)
FROM ubuntu:22.04 AS icu-compat
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libicu70 \
    && rm -rf /var/lib/apt/lists/* \
    && ARCH="$(uname -m)" \
    && mkdir -p /staging \
    && cp -a /usr/lib/${ARCH}-linux-gnu/libicu*.so.70* /staging/

# Stage 2: Ubuntu setup (user/group + runtime libraries)
FROM ubuntu:24.04 AS ubuntu-setup

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000

# Ubuntu 24.04 ships with a default 'ubuntu' user (UID/GID 1000); remove it
# only if it exists so we can claim GID 1000 for the CNB group without conflict.
# The conditional guards against failures when the base image ships without it.
#
# Install runtime libraries needed by language buildpacks (e.g. libyaml for
# Ruby's psych extension) so they can be injected into the distroless image.
# Libraries are staged under /staging so only the specific files we need are
# copied into the final distroless layer (keeps the image minimal).
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
    && cd "/usr/lib/${LIBDIR}" \
    && cp -a *.so* "/staging/usr/lib/${LIBDIR}/" \
    && cp -a "/lib/${LIBDIR}"/libssl*    "/staging/lib/${LIBDIR}/" \
    && cp -a "/lib/${LIBDIR}"/libcrypto* "/staging/lib/${LIBDIR}/"

# ---------------------------------------------------------------------------

FROM gcr.io/distroless/cc:nonroot

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

# Inject user/group data so the CNB lifecycle can resolve the cnb user.
COPY --from=ubuntu-setup /etc/passwd /etc/passwd
COPY --from=ubuntu-setup /etc/group  /etc/group

# Inject runtime libraries required by language buildpacks that are not
# present in the distroless base image.  The staging directory preserves the
# correct arch-specific path (x86_64-linux-gnu or aarch64-linux-gnu).
COPY --from=ubuntu-setup /staging/usr/lib/ /usr/lib/
COPY --from=ubuntu-setup /staging/lib/ /lib/

# Inject ICU 70 compatibility libraries for Paketo buildpack binaries.
COPY --from=icu-compat /staging/ /usr/lib/

# Inject timezone data and network configuration for apps that need them.
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

# Use the CNB user (1002) as the default unprivileged runtime user.
USER ${CNB_USER_ID}:${CNB_GROUP_ID}
