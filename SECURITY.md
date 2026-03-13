# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| `latest` (main) | ✅ |
| Tagged releases | ✅ |
| Older releases | Security fixes only |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

To report a security issue, please use one of the following channels:

1. **GitHub Security Advisories** – click **"Report a vulnerability"** in the
   [Security tab](https://github.com/patbaumgartner/distroless-buildpack-builder/security/advisories/new)
   of this repository.
2. **Email** – send a detailed report to the maintainers (see the repository
   profile for contact information).

### What to include

- Description of the vulnerability and its potential impact
- Steps to reproduce
- Affected component (build image, run image, builder, workflow, etc.)
- Any proof-of-concept code or screenshots

### Response timeline

| Stage | Target |
|-------|--------|
| Acknowledgement | 48 hours |
| Initial assessment | 5 business days |
| Fix or mitigation plan | 14 days (critical) / 30 days (others) |
| Public disclosure | Coordinated with reporter |

## Vulnerability Scanning

This repository runs continuous security scans:

| Tool | Scope | Frequency |
|------|-------|-----------|
| **Trivy** | Container images + filesystem | Every push + weekly |
| **Hadolint** | Dockerfile best practices | Every push |
| **CodeQL** | GitHub Actions workflows | Every push |
| **OSSF Scorecard** | Supply-chain security | Weekly |

All findings are published as SARIF reports to the
[Security tab](https://github.com/patbaumgartner/distroless-buildpack-builder/security/code-scanning).

## Security Design

### Run image (distroless)

The run image is based on `gcr.io/distroless/base-nossl:nonroot`:

- No shell binary (`/bin/sh`, `/bin/bash`, etc.)
- No package manager (`apt`, `apk`, etc.)
- No world-writable directories
- Runs as a non-root user (uid 1002, gid 1000)
- No SSL libraries (use `distroless/base` if your app needs SSL at runtime)

### Build image

The build image is based on `ubuntu:22.04`. It is only used during the build
phase and is **never present** in the final application image.

### Supply chain

- All base images are referenced by digest in production builds (via
  `docker/build-push-action` provenance and SBOM attestations).
- Dependabot is configured to open PRs for base image and action version updates
  weekly.
- GitHub Actions workflow permissions follow the principle of least privilege.
