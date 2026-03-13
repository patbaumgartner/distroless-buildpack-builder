REGISTRY       ?= ghcr.io/patbaumgartner/distroless-buildpack-builder
TAG            ?= latest
BUILDER_NAME   ?= distroless-builder
PACK           ?= pack

.PHONY: all build-stack build-builder test test-integration test-smoke clean lint

## ---------------------------------------------------------------------------
## High-level targets
## ---------------------------------------------------------------------------

all: build-stack build-builder

## Build both stack images and the builder.
build: build-stack build-builder

## Build the Ubuntu Jammy build-phase stack image and the Distroless run-phase
## stack image, then tag + push them to the registry.
build-stack: build-stack-build build-stack-run

build-stack-build:
	docker build \
	  --platform linux/amd64 \
	  --tag $(REGISTRY)/build:$(TAG) \
	  ./stack/build
	@echo "✔ Build stack image: $(REGISTRY)/build:$(TAG)"

build-stack-run:
	docker build \
	  --platform linux/amd64 \
	  --tag $(REGISTRY)/run:$(TAG) \
	  ./stack/run
	@echo "✔ Run stack image:   $(REGISTRY)/run:$(TAG)"

push-stack:
	docker push $(REGISTRY)/build:$(TAG)
	docker push $(REGISTRY)/run:$(TAG)

## Use 'pack' to assemble the builder from builder.toml and push to the registry.
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

## ---------------------------------------------------------------------------
## Testing
## ---------------------------------------------------------------------------

test: test-integration test-smoke

test-integration:
	@echo "Running integration tests..."
	bash ./tests/integration/test_builder.sh

test-smoke:
	@echo "Running smoke tests..."
	bash ./tests/smoke/smoke_test.sh

## ---------------------------------------------------------------------------
## Linting / Validation
## ---------------------------------------------------------------------------

lint:
	@echo "Validating builder.toml..."
	$(PACK) builder suggest 2>/dev/null || true
	@echo "Linting Dockerfiles with hadolint (if installed)..."
	@command -v hadolint >/dev/null 2>&1 && \
	  hadolint stack/build/Dockerfile stack/run/Dockerfile || \
	  echo "hadolint not found – skipping Dockerfile lint"

## ---------------------------------------------------------------------------
## Cleanup
## ---------------------------------------------------------------------------

clean:
	-docker rmi $(REGISTRY)/build:$(TAG)
	-docker rmi $(REGISTRY)/run:$(TAG)
	-docker rmi $(REGISTRY):$(TAG)
	@echo "✔ Cleaned local images"

## ---------------------------------------------------------------------------
## Help
## ---------------------------------------------------------------------------

help:
	@echo ""
	@echo "Distroless Buildpack Builder – Make targets"
	@echo "-------------------------------------------"
	@echo "  make build-stack      Build the build + run stack images"
	@echo "  make build-builder    Assemble the CNB builder image"
	@echo "  make push-stack       Push stack images to GHCR"
	@echo "  make push-builder     Push builder to GHCR via pack"
	@echo "  make test             Run integration + smoke tests"
	@echo "  make lint             Lint Dockerfiles and builder.toml"
	@echo "  make clean            Remove local Docker images"
	@echo ""
	@echo "  Variables:"
	@echo "    REGISTRY=$(REGISTRY)"
	@echo "    TAG=$(TAG)"
	@echo ""
