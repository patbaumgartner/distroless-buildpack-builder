REGISTRY       ?= ghcr.io/patbaumgartner/distroless-buildpack-builder
TAG            ?= latest
PLATFORMS      ?= linux/amd64,linux/arm64
PACK           ?= pack
DOCKER         ?= docker
PYTHON         ?= python3

# Local builds load a single-arch image into the Docker daemon so that
# `make test` works without registry credentials. Publishing the multi-arch
# images requires pushing, because buildx cannot --load a multi-platform
# result: use `make PUSH=1 build-stack`.
ifeq ($(PUSH),1)
BUILDX_OUTPUT := --platform $(PLATFORMS) --push
BUILDX_TARGET := $(PLATFORMS), pushed to $(REGISTRY)
else
BUILDX_OUTPUT := --load
BUILDX_TARGET := local daemon
endif

.PHONY: all build build-stack build-stack-build build-stack-run build-builder \
        push-builder test test-unit test-smoke test-integration \
        lint lint-dockerfiles lint-shell clean help

all: build

build: build-stack build-builder

build-stack: build-stack-build build-stack-run

build-stack-build:
	$(DOCKER) buildx build \
	  $(BUILDX_OUTPUT) \
	  --tag $(REGISTRY)/build:$(TAG) \
	  ./stack/build
	@echo "✔ Build stack image: $(REGISTRY)/build:$(TAG) [$(BUILDX_TARGET)]"

build-stack-run:
	$(DOCKER) buildx build \
	  $(BUILDX_OUTPUT) \
	  --tag $(REGISTRY)/run:$(TAG) \
	  ./stack/run
	@echo "✔ Run stack image:   $(REGISTRY)/run:$(TAG) [$(BUILDX_TARGET)]"

build-builder:
	$(PACK) builder create $(REGISTRY):$(TAG) \
	  --config ./builder.toml \
	  --pull-policy if-not-present
	@echo "✔ Builder image: $(REGISTRY):$(TAG)"

push-builder:
	$(PACK) builder create $(REGISTRY):$(TAG) \
	  --config ./builder.toml \
	  --publish
	@echo "✔ Builder pushed: $(REGISTRY):$(TAG)"

test: test-unit test-smoke test-integration

test-unit:
	$(PYTHON) -m unittest discover --start-directory tests/smoke

test-smoke:
	bash ./tests/smoke/smoke_test.sh

test-integration:
	bash ./tests/integration/test_builder.sh

lint: lint-dockerfiles lint-shell

lint-dockerfiles:
	@command -v hadolint >/dev/null 2>&1 || { \
	  echo "hadolint not found – see https://github.com/hadolint/hadolint" >&2; \
	  exit 1; \
	}
	hadolint stack/build/Dockerfile stack/run/Dockerfile

lint-shell:
	@command -v shellcheck >/dev/null 2>&1 || { \
	  echo "shellcheck not found – see https://www.shellcheck.net" >&2; \
	  exit 1; \
	}
	shellcheck tests/smoke/smoke_test.sh tests/integration/test_builder.sh

clean:
	-$(DOCKER) rmi $(REGISTRY)/build:$(TAG)
	-$(DOCKER) rmi $(REGISTRY)/run:$(TAG)
	-$(DOCKER) rmi $(REGISTRY):$(TAG)
	@echo "✔ Cleaned local images"

help:
	@echo ""
	@echo "Distroless Buildpack Builder"
	@echo ""
	@echo "  make build-stack       Build stack images (add PUSH=1 for multi-arch publish)"
	@echo "  make build-builder     Assemble the CNB builder image"
	@echo "  make push-builder      Push builder to registry via pack"
	@echo "  make test              Run unit + smoke + integration tests"
	@echo "  make test-unit         Validate builder.toml tooling (no Docker needed)"
	@echo "  make test-smoke        Check stack image contract (needs stack images)"
	@echo "  make test-integration  Build and probe every sample app"
	@echo "  make lint              Lint Dockerfiles (hadolint) and shell scripts"
	@echo "  make clean             Remove local Docker images"
	@echo ""
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  TAG=$(TAG)"
	@echo "  PLATFORMS=$(PLATFORMS)   (only used with PUSH=1)"
	@echo "  PUSH=$(if $(PUSH),$(PUSH),0)"
	@echo ""
