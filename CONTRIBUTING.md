# Contributing to distroless-buildpack-builder

Thank you for taking the time to contribute! 🎉

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Updating Buildpack Versions](#updating-buildpack-versions)

---

## Code of Conduct

This project follows the
[Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
By participating, you agree to abide by its terms.

---

## How to Contribute

### Reporting bugs

Please open a [GitHub Issue](https://github.com/patbaumgartner/distroless-buildpack-builder/issues/new)
with:
- A clear title
- Steps to reproduce
- Expected vs. actual behaviour
- Your `pack version` and `docker version` output

### Suggesting enhancements

Open an issue with the label `enhancement` and describe:
- The use-case or problem
- Your proposed solution
- Any alternatives you have considered

### Submitting code changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes following the guidelines below
4. Run the smoke tests (`make test-smoke`)
5. Commit with a descriptive message
6. Push and open a Pull Request against `main`

---

## Development Setup

### Prerequisites

| Tool | Minimum version |
|------|----------------|
| Docker | 20.10 |
| [pack CLI](https://buildpacks.io/docs/tools/pack/) | 0.33 |
| Java / Maven | JDK 21 (for Java sample + `mvn spring-boot:build-image`) |
| make | any recent version |
| hadolint (optional) | 2.x |

### Build locally

```bash
# Clone the repo
git clone https://github.com/patbaumgartner/distroless-buildpack-builder.git
cd distroless-buildpack-builder

# Build the two stack images (requires Docker)
make build-stack

# Assemble the CNB builder image (requires pack + Docker)
make build-builder

# Run the smoke tests
make test-smoke

# Run the full integration tests (requires running Docker + pack)
make test-integration
```

---

## Pull Request Process

1. **Tests** – All existing smoke tests must pass.
2. **Linting** – Run `make lint` and address any Hadolint warnings.
3. **Docs** – Update `README.md` if you change public-facing behaviour.
4. **One concern per PR** – Keep each PR focused on a single change to make
   reviews easier.

### Commit message style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(stack): upgrade distroless to latest nonroot tag
fix(builder): correct lifecycle version constraint
chore(deps): bump ubuntu base image to 22.04.4
docs: add section on custom stack IDs
```

---

## Updating Buildpack Versions

Pinned buildpack versions and the CNB lifecycle version in `builder.toml` are
managed automatically by **Renovate** (`.github/renovate.json`).  If you need
to update them manually:

1. Look up the current image tag on Docker Hub (e.g. `paketobuildpacks/procfile`).
2. Update the `uri` in the relevant `[[buildpacks]]` block in `builder.toml`.
3. Update the corresponding `version` in the matching `[[order.group]]` block.
4. Build and test locally before opening a PR.

---

## License

By contributing you agree that your contributions will be licensed under the
Apache 2.0 License.
