# ---------------------------------------------------------------------------
# Run stack image – used as the *runtime* base for built application images.
#
# Multi-stage build:
#   Stage 1 (ubuntu-setup): Creates the CNB user and group entries that must
#            appear in /etc/passwd and /etc/group in the final image.
#   Stage 2 (final):        Google Distroless base image with the user metadata
#            injected from Stage 1.  Distroless contains no shell, package
#            manager, or debug tools – providing a minimal attack surface.
#
# The CNB lifecycle (v0.18+) copies the compiled application and its launcher
# binary into this image at export time, so no shell is required at runtime.
# ---------------------------------------------------------------------------

FROM ubuntu:22.04 AS ubuntu-setup

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000

RUN groupadd --gid "${CNB_GROUP_ID}" cnb \
    && useradd \
       --uid  "${CNB_USER_ID}" \
       --gid  cnb \
       --no-create-home \
       cnb

# ---------------------------------------------------------------------------

FROM gcr.io/distroless/base-nossl:nonroot

ARG CNB_USER_ID=1002
ARG CNB_GROUP_ID=1000
ARG CNB_STACK_ID="io.buildpacks.stacks.jammy"

# Inject user/group data so the CNB lifecycle can resolve the cnb user.
COPY --from=ubuntu-setup /etc/passwd /etc/passwd
COPY --from=ubuntu-setup /etc/group  /etc/group

LABEL io.buildpacks.stack.id="${CNB_STACK_ID}"
LABEL io.buildpacks.base.distro.name="distroless"
LABEL io.buildpacks.base.distro.version="nonroot"
LABEL maintainer="patbaumgartner"
LABEL org.opencontainers.image.source="https://github.com/patbaumgartner/distroless-buildpack-builder"
LABEL org.opencontainers.image.description="Run stack image for the Distroless Buildpack Builder (Google Distroless base-nossl)"

# Use the CNB user (1002) as the default unprivileged runtime user.
USER ${CNB_USER_ID}:${CNB_GROUP_ID}
