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
| **Build stack** | `ubuntu:24.04` | Full toolchain for compiling apps |
| **Run stack** | `gcr.io/distroless/cc:nonroot` | Minimal, shell-free runtime with C++ runtime |
| **Builder** | CNB lifecycle + Paketo Buildpacks | Orchestrates builds |

The **build image** is an Ubuntu 24.04 Noble image with common build tools and
a non-root `cnb` user (UID 1000).  The **run image** is a Google Distroless
image with *no shell, no package manager, no debug tools* – drastically
reducing the attack surface of every application container built with this
builder.

---

## Supported Languages

| Language | Buildpack |
|----------|-----------|
| Java / Spring Boot | `paketo-buildpacks/java` || Java Native Image (GraalVM) | `paketo-buildpacks/java-native-image` || Go | `paketo-buildpacks/go` |
| Node.js | `paketo-buildpacks/nodejs` |
| Python | `paketo-buildpacks/python` |
| Ruby | `paketo-buildpacks/ruby` |
| PHP | `paketo-buildpacks/php` |
| .NET Core | `paketo-buildpacks/dotnet-core` |
| Procfile | `paketo-buildpacks/procfile` |

---

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.10
- [pack CLI](https://buildpacks.io/docs/tools/pack/) ≥ 0.33

### Build your application with `pack`

```bash
# Node.js application
pack build my-nodejs-app \
  --builder patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-nodejs-app

# Go application
pack build my-go-app \
  --builder patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-go-app

# Java / Spring Boot application
pack build my-java-app \
  --builder patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-java-app

# Java GraalVM Native Image application
pack build my-native-app \
  --builder patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-native-app
```

### Build a Spring Boot application with `mvn spring-boot:build-image`

The Spring Boot Maven plugin supports Cloud Native Buildpacks natively.
Configure the builder once in your `pom.xml`:

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <image>
      <builder>patbaumgartner/distroless-buildpack-builder:latest</builder>
      <pullPolicy>IF_NOT_PRESENT</pullPolicy>
    </image>
  </configuration>
</plugin>
```

Then build your image with a single Maven command – no Dockerfile required:

```bash
mvn spring-boot:build-image
```

Or override the builder on the command line without changing `pom.xml`:

```bash
mvn spring-boot:build-image \
  -Dspring-boot.build-image.builder=patbaumgartner/distroless-buildpack-builder:latest
```

The resulting image runs on a minimal Google Distroless base, giving you:
- ✅ No shell – smaller attack surface
- ✅ No package manager – nothing to exploit
- ✅ Non-root user by default
- ✅ Full Spring Boot / Actuator support (JVM is bundled by the Paketo buildpack)

### Set as default builder

```bash
pack config default-builder patbaumgartner/distroless-buildpack-builder:latest
pack build my-app
```

### Run the built image

```bash
docker run --rm -p 8080:8080 my-nodejs-app
```

---

## Registries

The builder and stack images are published to both **Docker Hub** and **GitHub
Container Registry (GHCR)** on every push to `main` and on every version tag.

### Docker Hub (recommended for general use)

```bash
docker pull patbaumgartner/distroless-buildpack-builder:latest        # Builder
docker pull patbaumgartner/distroless-buildpack-builder-build:latest  # Build stack
docker pull patbaumgartner/distroless-buildpack-builder-run:latest    # Run stack
```

### GitHub Container Registry

```bash
docker pull ghcr.io/patbaumgartner/distroless-buildpack-builder:latest        # Builder
docker pull ghcr.io/patbaumgartner/distroless-buildpack-builder/build:latest  # Build stack
docker pull ghcr.io/patbaumgartner/distroless-buildpack-builder/run:latest    # Run stack
```

| Image | Registry | Tag | Description |
|-------|----------|-----|-------------|
| `patbaumgartner/distroless-buildpack-builder` | Docker Hub | `latest` | CNB Builder |
| `patbaumgartner/distroless-buildpack-builder-build` | Docker Hub | `latest` | Build stack (Ubuntu 24.04) |
| `patbaumgartner/distroless-buildpack-builder-run` | Docker Hub | `latest` | Run stack (Distroless) |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder` | GHCR | `latest` | CNB Builder |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/build` | GHCR | `latest` | Build stack (Ubuntu 24.04) |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/run` | GHCR | `latest` | Run stack (Distroless) |

All images include SBOM (Software Bill of Materials) and build provenance
attestations in [SLSA](https://slsa.dev/) format.

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

## Sample Applications

The `samples/` directory contains ready-to-build applications for every major
language.  All samples expose a `/` and `/health` endpoint on port `8080`.

| Sample | Language | Build command |
|--------|----------|--------------|
| `samples/nodejs` | Node.js (Express 5) | `pack build my-app --path ./samples/nodejs --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/go` | Go | `pack build my-app --path ./samples/go --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/python` | Python (Flask + Gunicorn) | `pack build my-app --path ./samples/python --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/ruby` | Ruby (Sinatra + Puma) | `pack build my-app --path ./samples/ruby --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/dotnet-core` | .NET 9 (ASP.NET Core) | `pack build my-app --path ./samples/dotnet-core --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/php` | PHP | `pack build my-app --path ./samples/php --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/web-servers` | Static (Nginx) | `pack build my-app --path ./samples/web-servers --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/java` | Java 25 / Spring Boot (pack) | `pack build my-app --path ./samples/java --builder patbaumgartner/distroless-buildpack-builder:latest` |
| `samples/java` | Java 25 / Spring Boot (Maven) | `cd samples/java && mvn spring-boot:build-image` |
| `samples/java-native-image` | Java 25 / GraalVM Native Image | `pack build my-app --path ./samples/java-native-image --builder patbaumgartner/distroless-buildpack-builder:latest` |

---

## Repository Structure

```
.
├── builder.toml              # CNB builder configuration
├── Makefile                  # Local build automation
├── stack/
│   ├── build/Dockerfile      # Build stack image (Ubuntu 24.04 Noble)
│   └── run/Dockerfile        # Run stack image (Google Distroless)
├── samples/
│   ├── dotnet-core/          # ASP.NET Core sample application
│   ├── go/                   # Go HTTP sample application
│   ├── java/                 # Spring Boot sample (pack + mvn spring-boot:build-image)
│   ├── java-native-image/    # GraalVM Native Image sample (Spring Boot AOT)
│   ├── nodejs/               # Express.js sample application
│   ├── php/                  # PHP sample application
│   ├── python/               # Flask + Gunicorn sample application
│   ├── ruby/                 # Sinatra + Puma sample application
│   └── web-servers/          # Static files served by Nginx
├── tests/
│   ├── integration/          # End-to-end builder tests
│   └── smoke/                # Fast label + config validation tests
└── .github/
    ├── dependabot.yml        # Automated dependency updates (GitHub Actions, Docker, npm, Go, Maven, pip, Bundler, NuGet, Composer)
    └── workflows/
        ├── build-and-push.yml  # Build + push stack images + builder (GHCR + Docker Hub)
        ├── test.yml            # Smoke + integration tests (incl. mvn spring-boot:build-image)
        ├── security-scan.yml   # Trivy CVE scan + Hadolint Dockerfile lint
        ├── scorecard.yml       # OSSF Scorecard supply-chain security (weekly)
        ├── benchmark.yml       # Build-time + image-size benchmarks for all samples
        └── release.yml         # Create GitHub releases on version tags
```

---

## CI / CD

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Build and Push** | push to `main`, version tags | Build stack images + CNB builder, push to GHCR and Docker Hub with SBOM/provenance |
| **Integration Tests** | push, pull_request | Smoke tests → integration tests (pack + mvn spring-boot:build-image) |
| **Security Scan** | push, pull_request, weekly | Trivy CVE scan of container images + filesystem; Hadolint Dockerfile lint |
| **OSSF Scorecard** | push to `main`, weekly | Supply-chain security posture analysis |
| **Benchmark** | push to `main`, weekly | Measure build times + image sizes vs. Paketo baseline (all samples) |
| **Release** | version tags (`v*`) | Create a GitHub Release with notes and pull instructions |

---

## Security

The run image is based on `gcr.io/distroless/cc:nonroot`:

- **No shell** – attackers cannot execute shell commands
- **No package manager** – cannot install additional tools at runtime
- **Non-root user** (uid 1002) by default
- **C++ runtime included** (`libstdc++`, `libgcc`) – required by Node.js and other C++ runtimes

Security scanning is performed automatically:

- **Trivy** – CVE scanning of container images and filesystem (every push + weekly)
- **Hadolint** – Dockerfile best-practice linting (every push)
- **OSSF Scorecard** – Supply-chain security posture (weekly, dedicated workflow)

All images are signed with **SLSA build provenance** and include a **Software
Bill of Materials (SBOM)** accessible via:

```bash
docker buildx imagetools inspect \
  patbaumgartner/distroless-buildpack-builder:latest \
  --format '{{ json .SBOM }}'
```

Results are published to the **Security** tab of this repository as SARIF reports.

See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

Apache 2.0 – see [LICENSE](LICENSE).