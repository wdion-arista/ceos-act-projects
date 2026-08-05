# ceos-act-projects

This project wraps the [aristanetworks/aclabs](https://github.com/aristanetworks/aclabs) base container image with a structured command and lab deployment environment for managing customer AVD (Arista Validated Designs) deployments.

## Project Structure

### `common/`
Shared AVD Ansible commands, playbooks, group variables, and scripts used across all lab deployments. Mounted into the container at runtime.

### `containers/base/`
Docker build configuration for the base container image. Contains a copied (not symlinked) Dockerfile, requirements files, and wheelhouse that build on top of `ghcr.io/wdion-arista/aclabs/lab-base`. The `.devcontainer/` configs will eventually reference this location. `docker-compose.yml` here mounts `common/` and `labs/` into `/workspace/` at runtime.

### `labs/`
Customer deployment repos — each lab is a nested git repo containing its own Ansible `group_vars/` and `inventory/` files. This directory is gitignored; each lab is an independent git repo and is never tracked by this parent repo.

### `scripts/`
Host-side tooling for building an OrbStack macOS VM running Debian.

### `.devcontainer/`
VSCode devcontainer configurations for different environments (ACLABS, AVD versions, DinD vs DooD variants).

## Sensitive Files
- `.env` — local environment variables (tokens, passwords). Never committed.
- `.env_GH` — GitHub-specific credentials. Never committed.

## Container Design
The container image is built from `containers/base/Dockerfile`, which extends `ghcr.io/aristanetworks/aclabs/lab-base`. At runtime, `common/` and `labs/` are bind-mounted into `/workspace/`. Labs are isolated per-customer repos and are never tracked by this parent repo. The `.devcontainer/clab-dood-avd-aclabs/` config will eventually reference `containers/base/` instead of maintaining its own copy of these files.
