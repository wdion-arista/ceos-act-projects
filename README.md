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
