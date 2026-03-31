REGISTRY       ?= ghcr.io/patbaumgartner/distroless-buildpack-builder
TAG            ?= latest
PLATFORMS      ?= linux/amd64,linux/arm64
PACK           ?= pack

.PHONY: all build build-stack build-stack-build build-stack-run build-builder \
        push-builder test test-integration test-smoke lint clean help

all: build-stack build-builder

build: build-stack build-builder

# Multi-arch builds require buildx and push directly to the registry.
# docker buildx with --platform + multiple targets cannot --load locally.
build-stack: build-stack-build build-stack-run

build-stack-build:
	docker buildx build \
	  --platform $(PLATFORMS) \
	  --tag $(REGISTRY)/build:$(TAG) \
	  --push \
	  ./stack/build
	@echo "✔ Build stack image: $(REGISTRY)/build:$(TAG) [$(PLATFORMS)]"

build-stack-run:
	docker buildx build \
	  --platform $(PLATFORMS) \
	  --tag $(REGISTRY)/run:$(TAG) \
	  --push \
	  ./stack/run
	@echo "✔ Run stack image:   $(REGISTRY)/run:$(TAG) [$(PLATFORMS)]"

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

test: test-smoke test-integration

test-smoke:
	bash ./tests/smoke/smoke_test.sh

test-integration:
	bash ./tests/integration/test_builder.sh

lint:
	@command -v hadolint >/dev/null 2>&1 && \
	  hadolint stack/build/Dockerfile stack/run/Dockerfile || \
	  echo "hadolint not found – skipping Dockerfile lint"

clean:
	-docker rmi $(REGISTRY)/build:$(TAG)
	-docker rmi $(REGISTRY)/run:$(TAG)
	-docker rmi $(REGISTRY):$(TAG)
	@echo "✔ Cleaned local images"

help:
	@echo ""
	@echo "Distroless Buildpack Builder"
	@echo ""
	@echo "  make build-stack      Build + push multi-arch stack images (amd64, arm64)"
	@echo "  make build-builder    Assemble the CNB builder image"
	@echo "  make push-builder     Push builder to registry via pack"
	@echo "  make test             Run smoke + integration tests"
	@echo "  make lint             Lint Dockerfiles with hadolint"
	@echo "  make clean            Remove local Docker images"
	@echo ""
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  TAG=$(TAG)"
	@echo "  PLATFORMS=$(PLATFORMS)"
	@echo ""
