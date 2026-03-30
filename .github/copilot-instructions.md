# Copilot Instructions – Distroless Buildpack Builder

## Project Overview

This repository provides a **Cloud Native Buildpacks (CNB) builder** that
produces minimal, secure application images using **Google Distroless** as the
runtime base while supporting all major **Paketo Buildpacks** languages.

## Architecture

| Component | Base Image | Purpose |
|-----------|-----------|---------|
| Build stack | `ubuntu:24.04` | Full toolchain for compiling apps |
| Run stack | `gcr.io/distroless/cc:nonroot` | Minimal, shell-free runtime |
| Builder | CNB lifecycle + Paketo Buildpacks | Orchestrates builds via `pack` CLI |

## Key Files

- `builder.toml` — CNB builder configuration (lifecycle version, buildpacks, detection order, stack images)
- `stack/build/Dockerfile` — Build-phase stack image (Ubuntu 24.04 Noble)
- `stack/run/Dockerfile` — Run-phase stack image (Google Distroless)
- `Makefile` — Local build automation (`make build-stack`, `make build-builder`, `make test`)
- `renovate.json5` — Renovate config for builder.toml version tracking (custom regex manager)
- `.github/dependabot.yml` — Dependabot config for Actions, Docker, npm, Go, Maven, pip, Bundler, NuGet, Composer

## Sample Applications

All samples are in `samples/` and expose `/` and `/health` on port `8080`:

| Directory | Language | Notes |
|-----------|----------|-------|
| `samples/nodejs` | Node.js (Express 5) | |
| `samples/go` | Go | |
| `samples/python` | Python (Flask) | |
| `samples/ruby` | Ruby (Sinatra) | |
| `samples/dotnet-core` | .NET 9 (ASP.NET Core) | |
| `samples/php` | PHP | |
| `samples/web-servers` | Static (Nginx) | |
| `samples/java` | Java 25 / Spring Boot | Also supports `mvn spring-boot:build-image` |
| `samples/java-native-image` | Java 25 / GraalVM Native Image | Spring Boot AOT compilation |

When adding a new sample, also update:
1. `.github/workflows/benchmark.yml` — add to the matrix
2. `.github/workflows/test.yml` — add pack build + container verification steps
3. `.github/dependabot.yml` — add dependency tracking for the ecosystem
4. `tests/integration/test_builder.sh` — add to the test loop
5. `README.md` — samples table, repo structure, CI/CD description

## CI/CD Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| Build and Push | `build-and-push.yml` | Build stack images + CNB builder, push to GHCR + Docker Hub |
| Integration Tests | `test.yml` | Smoke tests (CNB labels) → integration tests (pack + mvn) |
| Security Scan | `security-scan.yml` | Trivy CVE scan + Hadolint Dockerfile lint |
| OSSF Scorecard | `scorecard.yml` | Supply-chain security posture (weekly) |
| Benchmark | `benchmark.yml` | Build-time + image-size benchmarks for all samples |
| Release | `release.yml` | GitHub Release on version tags (`v*`) |

## Registries

Images are published to both **GHCR** and **Docker Hub**:
- GHCR: `ghcr.io/patbaumgartner/distroless-buildpack-builder`
- Docker Hub: `patbaumgartner/distroless-buildpack-builder`

## Conventions

- **Secrets**: Docker Hub credentials use `DOCKER_USERNAME` / `DOCKER_PASSWORD`
- **Env vars**: Workflows define `IMAGE_BASE` for the full GHCR image path
- **Trivy**: Pinned to a specific version in `security-scan.yml`
- **Commit messages**: Follow conventional commits (`chore:`, `feat:`, `fix:`, `ci:`)
- **Dependency updates**: Dependabot handles Actions, Docker, npm, Go, Maven, pip, Bundler, NuGet, Composer; Renovate handles `builder.toml` (buildpacks + lifecycle)

## Building Locally

```bash
make build-stack      # Build stack images
make build-builder    # Create CNB builder
make test             # Run integration + smoke tests
```

## Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers `release.yml` (GitHub Release) and `build-and-push.yml` (versioned images).
