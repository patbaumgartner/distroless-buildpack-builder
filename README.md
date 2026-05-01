# distroless-buildpack-builder

[![Build and Push](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/build-and-push.yml)
[![Integration Tests](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/test.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/test.yml)
[![Security Scan](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/security-scan.yml/badge.svg)](https://github.com/patbaumgartner/distroless-buildpack-builder/actions/workflows/security-scan.yml)

A [Cloud Native Buildpacks](https://buildpacks.io) builder that produces minimal, secure application images using [Google Distroless](https://github.com/GoogleContainerTools/distroless) as the runtime base, while supporting all major [Paketo Buildpacks](https://paketo.io) languages.

| Component | Base image | Purpose |
|-----------|-----------|---------|
| **Build stack** | `ubuntu:24.04` | Full toolchain for compiling apps |
| **Run stack** | `gcr.io/distroless/cc:nonroot` | Minimal, shell-free runtime |
| **Builder** | CNB lifecycle + Paketo Buildpacks | Orchestrates builds |

The run image has **no shell, no package manager, no debug tools** — drastically reducing the attack surface of every application container built with this builder.

## Supported Languages

| Language | Buildpack |
|----------|-----------|
| Java / Spring Boot | `paketo-buildpacks/java` |
| Java Native Image (GraalVM) | `paketo-buildpacks/java-native-image` |
| Go | `paketo-buildpacks/go` |
| Node.js | `paketo-buildpacks/nodejs` |
| Python | `paketo-buildpacks/python` |
| Ruby | `paketo-buildpacks/ruby` |
| PHP | `paketo-buildpacks/php` |
| .NET Core | `paketo-buildpacks/dotnet-core` |
| Procfile | `paketo-buildpacks/procfile` |

## Quick Start

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) ≥ 20.10, [pack CLI](https://buildpacks.io/docs/tools/pack/) ≥ 0.33

```bash
pack build my-app \
  --builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest \
  --path ./my-app
```

### Set as default builder

```bash
pack config default-builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest
pack build my-app
```

### Spring Boot with Maven

Configure once in `pom.xml`:

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <image>
      <builder>ghcr.io/patbaumgartner/distroless-buildpack-builder:latest</builder>
      <pullPolicy>IF_NOT_PRESENT</pullPolicy>
    </image>
  </configuration>
</plugin>
```

Then build:

```bash
mvn spring-boot:build-image

# or override the builder without changing pom.xml:
mvn spring-boot:build-image \
  -Dspring-boot.build-image.builder=ghcr.io/patbaumgartner/distroless-buildpack-builder:latest
```

## Images

Images are published to **GHCR** on pushes to `main`, on version tags, and during scheduled refresh runs in CI. Pull requests execute build validation but do not publish images. Images include [SLSA](https://slsa.dev/) provenance attestations.

OCI-attached SBOM/provenance manifests are disabled during stack-image `docker buildx` publish steps due to a known CNB manifest-selection compatibility issue in `pack`; however, SBOM artifacts are still generated separately with Syft in CI.

| Image | Registry |
|-------|----------|
| `ghcr.io/patbaumgartner/distroless-buildpack-builder` | GHCR |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/build` | GHCR |
| `ghcr.io/patbaumgartner/distroless-buildpack-builder/run` | GHCR |

## Building Locally

**Prerequisites:** Docker with buildx, pack CLI, `make`

```bash
make build-stack    # Build + push multi-arch stack images (amd64, arm64)
make build-builder  # Assemble the CNB builder image
make test           # Run smoke + integration tests
make test-smoke     # Run smoke tests only (fast)
make test-integration # Run integration tests only
```

To include Java samples in integration tests:

```bash
INCLUDE_JAVA=1 make test-integration
```

> **Note:** `make build-stack` uses `docker buildx build --push` to produce multi-arch images (`linux/amd64` + `linux/arm64`). It pushes directly to the registry — local loading of multi-platform images is not supported by Docker. Set `PLATFORMS=linux/amd64` to restrict to a single architecture.

## Sample Applications

All samples in `samples/` expose `/` and `/health` on port `8080`.

| Sample | Language |
|--------|----------|
| `samples/nodejs` | Node.js (Express 5) |
| `samples/go` | Go |
| `samples/python` | Python (Flask) |
| `samples/ruby` | Ruby (Sinatra) |
| `samples/dotnet-core` | .NET (ASP.NET Core) |
| `samples/php` | PHP |
| `samples/web-servers` | Static (Nginx) |
| `samples/java` | Java 25 / Spring Boot |
| `samples/java-native-image` | Java 25 / GraalVM Native Image |

Build any sample:

```bash
pack build my-app \
  --path ./samples/nodejs \
  --builder ghcr.io/patbaumgartner/distroless-buildpack-builder:latest
```

## Repository Structure

```text
├── builder.toml              # CNB builder configuration
├── Makefile                  # Local build automation
├── CODE_OF_CONDUCT.md        # Community behavior expectations
├── SUPPORT.md                # Support and triage guidance
├── benchmarks/
│   └── budgets.json           # Build/runtime SLO budgets
├── openrewrite/
│   └── rewrite.yml            # Curated OpenRewrite recipe packs
├── stack/
│   ├── build/Dockerfile      # Build stack image (Ubuntu 24.04)
│   └── run/Dockerfile        # Run stack image (Google Distroless)
├── samples/                  # Ready-to-build sample apps per language
├── tests/
│   ├── integration/          # End-to-end builder tests
│   └── smoke/                # Fast label + config validation
└── .github/
    ├── ISSUE_TEMPLATE/       # Bug report and feature request templates
    ├── dependabot.yml        # Automated dependency updates
    └── workflows/
        ├── build-and-push.yml  # Build + push to GHCR
        ├── test.yml            # Smoke + integration tests
        ├── security-scan.yml   # Trivy CVE scan + Hadolint lint
        ├── scorecard.yml       # OSSF Scorecard (weekly)
        ├── benchmark.yml       # Build-time + runtime/startup/memory benchmarks
        ├── quality-gates.yml   # Linting, static analysis, and Checkstyle
        ├── openrewrite.yml     # OpenRewrite dry-run + scheduled modernization PRs
        ├── dependency-policy-review.yml # Quarterly dependency policy review issue
        └── release.yml         # GitHub releases on version tags
```

## CI/CD

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Build and Push** | push to `main`, pull_request, version tags, daily | Build/validate stack images + builder; publish on non-PR events |
| **Integration Tests** | push, pull_request | Smoke tests → integration tests (pack + mvn) |
| **Security Scan** | push, pull_request, weekly | Trivy CVE scan (filesystem + stack images) + Hadolint Dockerfile lint |
| **OSSF Scorecard** | push to `main`, weekly | Supply-chain security posture analysis |
| **Benchmark** | after Build and Push, weekly | Build times + startup + memory + run image size SLOs |
| **Quality Gates** | push, pull_request | Linting (ShellCheck, actionlint, markdownlint), sample static analysis, and Checkstyle |
| **OpenRewrite** | push, pull_request, monthly | Java dry-run recipe checks + scheduled modernization PR |
| **Dependency Policy Review** | quarterly | Opens governance checklist issue for dependency strategy review |
| **Release** | version tags (`v*`) | GitHub Release with pull instructions |

## Cost and Resource Efficiency

To detect when workloads become more expensive to run, CI enforces explicit budgets in `benchmarks/budgets.json`:

- Build-time SLO per sample (seconds)
- Runtime startup SLO per sample (seconds)
- Runtime memory SLO per sample (MiB)
- Maximum distroless run image size (MB)

The benchmark workflow persists machine-readable metric artifacts for each run, which enables trend analysis over time and early detection of resource-cost regressions.

## Security

The run image (`gcr.io/distroless/cc:nonroot`) provides:

- No shell — attackers cannot execute shell commands
- No package manager — nothing installable at runtime
- Non-root user (uid 1002) by default
- C++ runtime (`libstdc++`, `libgcc`) included for Node.js and other C++ runtimes

Automated scanning on every push:

- **Trivy** — CVE scanning of repository filesystem plus local build/run stack images
- **Hadolint** — Dockerfile best-practice linting (blocking)
- **Quality Gates** — blocking static-analysis checks across scripts, workflows, docs, and sample applications
- **OSSF Scorecard** — Supply-chain security posture (weekly)

SARIF reports are published to the [Security tab](https://github.com/patbaumgartner/distroless-buildpack-builder/security/code-scanning).

See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).
