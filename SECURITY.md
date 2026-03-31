# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| `latest` (main) | ✅ |
| Tagged releases | ✅ |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Use one of these channels:

1. **GitHub Security Advisories** — click **"Report a vulnerability"** in the [Security tab](https://github.com/patbaumgartner/distroless-buildpack-builder/security/advisories/new)
2. **Email** — contact the maintainers (see repository profile)

Include: description, potential impact, steps to reproduce, affected component, and any proof-of-concept.

| Stage | Target |
|-------|--------|
| Acknowledgement | 48 hours |
| Initial assessment | 5 business days |
| Fix or mitigation | 14 days (critical) / 30 days (others) |
| Public disclosure | Coordinated with reporter |

## Automated Scanning

| Tool | Scope | Frequency |
|------|-------|-----------|
| **Trivy** | Repository filesystem + local build/run stack images | Every push + weekly |
| **Hadolint** | Dockerfile best practices | Every push |
| **Quality Gates** | Shell scripts, workflows, Markdown, language samples | Every push + pull request |
| **OSSF Scorecard** | Supply-chain security | Weekly |

SARIF reports are published to the [Security tab](https://github.com/patbaumgartner/distroless-buildpack-builder/security/code-scanning).

## Security Design

**Run image** (`gcr.io/distroless/cc:nonroot`):

- No shell, no package manager, no world-writable directories
- Non-root user (uid 1002, gid 1000)
- C++ runtime included (`libstdc++`, `libgcc`)

**Build image** (`ubuntu:24.04`): used only during builds, never present in final application images.

**Supply chain**:

- Base images referenced by digest in production builds (SLSA provenance attestations)
- OCI-attached SBOM/provenance manifests are disabled during stack-image publish because of a known CNB manifest-selection compatibility issue, while CI still generates SBOM artifacts with Syft
- Dependabot opens PRs for base image and action updates weekly
- GitHub Actions workflow permissions follow least privilege
