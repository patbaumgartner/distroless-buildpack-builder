# Copilot Instructions – Distroless Buildpack Builder

## Architecture

| Component | Base Image | Purpose |
|-----------|-----------|---------|
| Build stack | `ubuntu:24.04` | Full toolchain for compiling apps |
| Run stack | `gcr.io/distroless/cc:nonroot` | Minimal, shell-free runtime |
| Builder | CNB lifecycle + Paketo Buildpacks | Orchestrates builds via `pack` CLI |

## Key Files

- `builder.toml` — CNB builder config (lifecycle version, buildpacks, detection order, stack images)
- `stack/build/Dockerfile` — Build-phase stack image (Ubuntu 24.04)
- `stack/run/Dockerfile` — Run-phase stack image (Google Distroless, multi-stage)
- `Makefile` — Local build automation (multi-arch via `docker buildx`)
- `renovate.json5` — Renovate config for `builder.toml` version tracking (custom regex manager)
- `.github/dependabot.yml` — Dependabot for Actions, Docker, npm, Go, Maven, pip, Bundler, NuGet, Composer
- `benchmarks/budgets.json` — SLO performance budgets (build time, startup, memory per sample)
- `openrewrite/rewrite.yml` — OpenRewrite recipe config for Java modernization
- `CONTRIBUTING.md` — Contribution guidelines, dev setup, PR requirements
- `SECURITY.md` — Vulnerability reporting policy, SLA targets, automated scanning overview

## Quality Config

- `.shellcheckrc` — ShellCheck config: `severity=style`, excludes SC1091
- `.markdownlint.yml` — markdownlint config: disables MD013, MD033, MD041, MD060
- `.gitattributes` — Enforces LF line endings for all text files

## Sample Applications

All samples in `samples/` expose `/` and `/health` on port `8080`:

| Directory | Language |
|-----------|----------|
| `samples/nodejs` | Node.js (Express 5) |
| `samples/go` | Go |
| `samples/python` | Python (Flask) |
| `samples/ruby` | Ruby (Sinatra) |
| `samples/dotnet-core` | .NET (ASP.NET Core) |
| `samples/php` | PHP |
| `samples/web-servers` | Static (Nginx) |
| `samples/java` | Java 25 / Spring Boot (also supports `mvn spring-boot:build-image`) |
| `samples/java-native-image` | Java 25 / GraalVM Native Image |

When adding a new sample, update:
1. `.github/workflows/benchmark.yml` — add to the matrix
2. `.github/workflows/test.yml` — add pack build + container verification steps
3. `.github/workflows/quality-gates.yml` — add language-specific static analysis step
4. `.github/dependabot.yml` — add dependency tracking for the ecosystem
5. `tests/integration/test_builder.sh` — add to the test loop
6. `benchmarks/budgets.json` — add SLO budgets for the new sample
7. `README.md` — samples table

## CI/CD Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| Build and Push | `build-and-push.yml` | Build stack images + builder, push to GHCR |
| Integration Tests | `test.yml` | Smoke tests (CNB labels) → integration tests (pack + mvn) |
| Quality Gates | `quality-gates.yml` | Linting (ShellCheck, actionlint, markdownlint), per-language static analysis, and Checkstyle |
| Security Scan | `security-scan.yml` | Trivy CVE scan (advisory, SARIF upload) + Hadolint Dockerfile lint |
| OSSF Scorecard | `scorecard.yml` | Supply-chain security posture (weekly) |
| Benchmark | `benchmark.yml` | Build-time + runtime footprint benchmarks with SLO budget enforcement |
| OpenRewrite | `openrewrite.yml` | Monthly dry-run / apply of Java modernization recipes (auto-PR) |
| Dependency Policy | `dependency-policy-review.yml` | Quarterly governance review — auto-creates audit checklist issue |
| Release | `release.yml` | GitHub Release on version tags (`v*`) |

## Quality Gates Details

**Lint automation** (`quality-gates.yml` → `lint-automation` job):
- ShellCheck (style severity) on all `tests/**/*.sh`
- actionlint on all workflow files
- markdownlint on all Markdown (excludes `samples/php/vendor`)

**Language static analysis** (`quality-gates.yml` → `language-static-analysis` job):
- Node.js: `node --check`
- Go: `gofmt -l`, `go test`, `go vet`
- Python: `ruff check`, `mypy`
- Ruby: `ruby -wc`
- PHP: `php -l`, `composer validate`
- .NET: `dotnet build -warnaserror`
- Java: `mvn test` (both `java` and `java-native-image`)

**Checkstyle** (`quality-gates.yml` → `checkstyle` job):
- Google Java style enforcement via `mvn checkstyle:check` (both `java` and `java-native-image`)

## Benchmark SLO Budgets

Performance budgets are defined in `benchmarks/budgets.json` and enforced in CI:
- **Build time** — average build duration must stay under budget (per sample)
- **Startup time** — container must respond within budget seconds
- **Memory** — RSS must stay under budget MiB
- **Run image size** — capped at `run_image_max_mb`

Metric artifacts (JSON) are uploaded for each benchmark run.

## Conventions

- **Env vars**: Workflows define `IMAGE_BASE` for the full GHCR image path
- **Trivy**: Pinned to a specific version in `security-scan.yml`; advisory mode (`exit-code: 0`), results uploaded to Security tab via SARIF
- **Commit messages**: Conventional commits (`chore:`, `feat:`, `fix:`, `ci:`, `docs:`)
- **Dependency updates**: Dependabot handles all ecosystems; Renovate handles `builder.toml` (buildpacks + lifecycle)
- **Line endings**: LF enforced via `.gitattributes`
- **Shell style**: ShellCheck at `severity=style`; use grouped redirects (`{ ...; } >> file`) instead of repeated appends

## Building Locally

```bash
make build-stack       # Build multi-arch stack images (amd64 + arm64)
make build-builder     # Create CNB builder
make test              # Run smoke + integration tests
make test-smoke        # Smoke tests only
make test-integration  # Integration tests only (set INCLUDE_JAVA=1 for Java samples)
make lint              # Lint Dockerfiles with hadolint
make clean             # Remove local Docker images
make help              # List all available targets
```

Configurable variables: `REGISTRY`, `TAG`, `PLATFORMS` (default: `linux/amd64,linux/arm64`), `PACK`.

## Testing

- **Smoke tests** (`tests/smoke/smoke_test.sh`): Stack image labels, `builder.toml` validation, builder inspection, Dockerfile hadolint
- **Integration tests** (`tests/integration/test_builder.sh`): `pack build` → run container → verify `/` and `/health` endpoints → cleanup. Java samples gated behind `INCLUDE_JAVA=1`

## Creating a Release

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Triggers `release.yml` (GitHub Release) and `build-and-push.yml` (versioned images).
