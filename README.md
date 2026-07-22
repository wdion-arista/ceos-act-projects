# cEOS-lab 101

This repository wraps the [wdion-arista/aclabs](https://github.com/wdion-arista/aclabs) base container image with a structured command and lab deployment environment for managing customer AVD (Arista Validated Designs) deployments.

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/wdion-arista/ceos-act-projects.git
cd ceos-act-projects
```

### 2. Initialize the MandE lab submodule

```bash
git submodule update --init labs/MandE
```

To initialize all submodules at once:

```bash
git submodule update --init --recursive
```

## Mac Setup

For OrbStack and cEOSarm installation on macOS, see the [OrbStack cEOS Mac Install guide](docs/orbstack-ceos-mac-install.md).

## GitHub Actions Setup (for forks / template users)

The `main`-branch publish jobs in [.github/workflows/containers-base-publish.yml](.github/workflows/containers-base-publish.yml) and [.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml) are gated on a GitHub Environment named `production`. Without it, those jobs will hang waiting for an approval reviewer that doesn't exist.

To enable them in your fork or template-derived repo:

1. Go to **Settings → Environments → New environment**.
2. Name it `production` (exact match).
3. Optionally add required reviewers, wait timers, or environment secrets — leave empty for unattended builds.

Branch builds (any branch other than `main`) and release tagging do not require this environment.
