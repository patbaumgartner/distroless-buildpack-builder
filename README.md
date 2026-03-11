# distroless-buildpack-builder

[![Build and Push](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/build-and-push.yml)
[![Integration Tests](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/test.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/test.yml)
[![Security Scan](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/security-scan.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/security-scan.yml)

A [Cloud Native Buildpacks](https://buildpacks.io) **builder** that produces
minimal, secure application images using
[Google Distroless](https://github.com/GoogleContainerTools/distroless) as the
runtime base, while supporting all major
[Paketo Buildpacks](https://paketo.io) languages.

---

## Overview

| Component | Base image | Purpose |
|-----------|-----------|---------|
| **Build stack** | `ubuntu:22.04` | Full toolchain for compiling apps |
| **Run stack** | `gcr.io/distroless/base-nossl:nonroot` | Minimal, shell-free runtime |
| **Builder** | CNB lifecycle + Paketo Buildpacks | Orchestrates builds |

The **build image** is a standard Ubuntu 22.04 Jammy image with common build
tools.  The **run image** is a Google Distroless image with *no shell, no
package manager, no debug tools* – drastically reducing the attack surface of
every application container built with this builder.

---

## Supported Languages

| Language | Buildpack |
|----------|-----------|
| Java (JVM) | `paketo-buildpacks/java` |
| Go | `paketo-buildpacks/go` |
| Node.js | `paketo-buildpacks/nodejs` |
| Python | `paketo-buildpacks/python` |
| Ruby | `paketo-buildpacks/ruby` |
| PHP | `paketo-buildpacks/php` |
| .NET Core | `paketo-buildpacks/dotnet-core` |
| Rust | `paketo-buildpacks/rust` |
| NGINX | `paketo-buildpacks/nginx` |
| Procfile | `paketo-buildpacks/procfile` |

---

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.10
- [pack CLI](https://buildpacks.io/docs/tools/pack/) ≥ 0.33

### Build your application

```bash
# Node.js application
pack build my-nodejs-app \
  --builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-nodejs-app

# Go application
pack build my-go-app \
  --builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-go-app

# Java / Spring Boot application
pack build my-java-app \
  --builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-java-app
```

### Set as default builder

```bash
pack config default-builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest
pack build my-app
```

### Run the built image

```bash
docker run --rm -p 8080:8080 my-nodejs-app
```

---

## Stack Images

Both stack images are automatically published to GitHub Container Registry on
every push to `main` and on every version tag (`v*`).

| Image | Tag | Description |
|-------|-----|-------------|
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/build` | `latest` | Build stack (Ubuntu 22.04) |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/run` | `latest` | Run stack (Distroless) |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder` | `latest` | CNB Builder |

---

## Building Locally

### Prerequisites (local)

- [Docker](https://docs.docker.com/get-docker/)
- [pack CLI](https://buildpacks.io/docs/tools/pack/)
- `make`

### Build the stack images

```bash
make build-stack
```

### Build the CNB builder image

```bash
make build-builder
```

### Run all tests

```bash
make test
```

### Run smoke tests only (fast)

```bash
make test-smoke
```

---

## Repository Structure

```
.
├── builder.toml              # CNB builder configuration
├── Makefile                  # Local build automation
├── stack/
│   ├── build/Dockerfile      # Build stack image (Ubuntu 22.04 Jammy)
│   └── run/Dockerfile        # Run stack image (Google Distroless)
├── samples/
│   ├── java/                 # Spring Boot sample application
│   ├── nodejs/               # Express.js sample application
│   └── go/                   # Go HTTP sample application
├── tests/
│   ├── integration/          # End-to-end builder tests
│   └── smoke/                # Fast label + config validation tests
└── .github/
    ├── dependabot.yml        # Automated dependency updates
    └── workflows/
        ├── build-and-push.yml  # Build + push stack images + builder
        ├── test.yml            # Integration tests
        ├── security-scan.yml   # Trivy, Hadolint, CodeQL, OSSF Scorecard
        ├── benchmark.yml       # Build-time + image-size benchmarks
        └── release.yml         # Create GitHub releases on version tags
```

---

## CI / CD

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Build and Push** | push to `main`, version tags | Build stack images + CNB builder, push to GHCR |
| **Integration Tests** | push, pull_request | Build sample apps with the builder, verify they run |
| **Security Scan** | push, pull_request, weekly | Trivy CVE scan, Hadolint, CodeQL, OSSF Scorecard |
| **Benchmark** | push to `main`, weekly | Measure build times + image sizes vs. Paketo baseline |
| **Release** | version tags (`v*`) | Create a GitHub Release with notes and pull instructions |

---

## Security

The run image is based on `gcr.io/distroless/base-nossl:nonroot`:

- **No shell** – attackers cannot execute shell commands
- **No package manager** – cannot install additional tools at runtime
- **Non-root user** (uid 1002) by default
- **No libc SSL** (`base-nossl`) – use when your app handles TLS itself

Security scanning is performed on every push using:

- **Trivy** – CVE scanning of container images and filesystem
- **Hadolint** – Dockerfile best-practice linting
- **CodeQL** – Static analysis of GitHub Actions workflows
- **OSSF Scorecard** – Supply-chain security posture (weekly)

Results are published to the **Security** tab of this repository as SARIF reports.

See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

Apache 2.0 – see [LICENSE](LICENSE).