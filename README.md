# ceos-act-projects

A structured lab deployment environment for managing Arista AVD (Arista Validated Designs) configurations across three targets: **ContainerLab** (local cEOS), **ACT** (Arista Cloud Test), and **CVaaS/CVP** (production). Built on the [aristanetworks/aclabs](https://github.com/aristanetworks/aclabs) base container image, it provides shared Ansible playbooks, a common Makefile with 80+ targets, and per-lab devcontainer configs — so every lab gets a consistent, reproducible workflow out of the box.

The **[MandE demo lab](labs/MandE/)** is included as a submodule and serves as the reference template for building your own labs.

---

## Prerequisites

- **Docker** (Moby) — see [Environment Setup](#environment-setup) for your platform
- **VSCode** with the [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) and [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extensions
- An **[arista.com](https://www.arista.com/en/users/profile)** account for downloading cEOS images (`ARISTA_TOKEN`)
- **`devcontainer` CLI** (optional — the [`start`](#the-start-script) script will offer to install it if missing)

---

## Quick Start

### 1. Clone the repo and initialize the MandE demo lab

```bash
git clone https://github.com/wdion-arista/ceos-act-projects.git
cd ceos-act-projects
git submodule update --init labs/MandE
```

### 2. Set up your environment

Follow the instructions for your platform:

| Platform | Section |
| --- | --- |
| macOS (Apple Silicon / Intel) | [macOS Setup (OrbStack)](#macos-orbstack) |
| Windows | [Windows Setup (WSL2 + Moby)](#windows-wsl2--moby) |
| Linux | [Linux Setup](#linux-native) |

### 3. Open the devcontainer

Once Docker is running, open the `ceos-act-projects` folder in VSCode, then **Reopen in Container** and select a devcontainer config:

| Config | Image | Lab |
| --- | --- | --- |
| `ceos-act-projects-base-MandE` | `base` (no AI tools) | MandE |
| `ceos-act-projects-base-ai-MandE` | `base-ai` (includes Claude Code) | MandE |

Or use the [`start`](#the-start-script) script to pick a lab and launch automatically:

```bash
./start
```

### 4. Run the MandE demo lab

Inside the container, see the [MandE Demo Lab](#the-mande-demo-lab) section below for `.env` setup and key `make` targets.

---

## Project Structure

```
ceos-act-projects/
├── common/                  # Shared across all labs
│   ├── Makefile-common.mk   #   80+ make targets (build, deploy, validate, …)
│   ├── playbooks/           #   Ansible playbooks
│   ├── global_vars/         #   Global Ansible variables (credentials, NTP, banners, …)
│   └── scripts/             #   Utility scripts (inventory processing, diagrams, …)
├── containers/base/         # Container image build
│   ├── Dockerfile           #   Extends aclabs/lab-base with project tools
│   ├── docker-compose.yml   #   Bind-mounts common/ and labs/ into /workspace/
│   ├── endpoint.sh          #   Entrypoint: cEOS import, token gen, code-server
│   ├── requirements.txt     #   Python dependencies
│   └── requirements.yml     #   Ansible Galaxy roles & collections
├── labs/                    # Per-customer lab repos (each an independent git repo)
│   └── MandE/               #   Template / demo lab (submodule)
├── .devcontainer/           # VSCode devcontainer configs (one per lab)
├── scripts/                 # Host-side setup tooling
│   └── debian/              #   OrbStack / Debian VM setup (shell-init.sh, cloud-config.yml)
├── docs/                    # Setup guides
│   └── orbstack-ceos-mac-install.md
└── start                    # Lab launcher script
```

Each lab under `labs/` is an independent git repo containing its own `Makefile`, `inventory.yml`, `group_vars/`, and site definitions. The lab's `Makefile` includes `common/Makefile-common.mk` to inherit all shared targets.

---

## Environment Setup

### macOS (OrbStack)

OrbStack provides an ARM64 Linux VM with near-native performance on Apple Silicon. Docker (Moby) runs inside the VM, and VSCode connects via Remote SSH.

1. **Install OrbStack**

   ```bash
   brew install orbstack
   ```

2. **Run the setup script** — configures OrbStack resources and generates `cloud-config.yml`

   ```bash
   cd scripts/debian
   ./shell-init.sh          # Defaults: 8 CPU, 24 GB RAM
   # Or specify resources:
   ./shell-init.sh 8 28     # 8 CPU, 28 GB RAM
   ```

3. **Create the ARM64 Debian VM**

   ```bash
   orb create -a arm64 debian debian --user-data cloud-config.yml
   ```

4. **Log in and add your user to the docker group**

   ```bash
   ssh orb
   sudo usermod -aG docker $USER
   ```

5. **Connect VSCode** — use the Remote SSH extension to connect to `orb`, open the `ceos-act-projects` folder, then **Reopen in Container**

For detailed steps with screenshots, see the [OrbStack cEOS Mac Install guide](docs/orbstack-ceos-mac-install.md).

#### macOS network routing (optional)

To reach container management IPs (e.g. `172.20.20.x`) directly from your Mac:

```bash
scripts/debian/add-docker-routes.sh
```

---

### Windows (WSL2 + Moby)

This setup installs Docker Engine (Moby) directly inside a WSL2 Debian distro — no Docker Desktop required.

1. **Install WSL2 with Debian**

   Open PowerShell as Administrator:

   ```powershell
   wsl --install -d Debian
   ```

   Restart if prompted, then launch the Debian terminal to complete setup.

2. **Install Docker (Moby) inside WSL2**

   The same packages used by the OrbStack VM setup work in WSL2. Inside your Debian terminal:

   ```bash
   # Install prerequisites
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg lsb-release

   # Add Microsoft GPG key and Moby repo
   curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
     gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null

   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] \
     https://packages.microsoft.com/debian/12/prod bookworm main" | \
     sudo tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null

   sudo apt-get update

   # Install Moby
   sudo apt-get install -y moby-engine moby-cli moby-buildx moby-compose

   # Create docker group and add your user
   sudo groupadd -g 2020 docker
   sudo usermod -aG docker $USER

   # Create the netns directory (needed for ContainerLab)
   sudo mkdir -p /run/docker/netns
   sudo chown root:docker /run/docker/netns

   # Start Docker
   sudo service docker start
   ```

   > These steps mirror [`scripts/debian/cloud-config.yml`](scripts/debian/cloud-config.yml) — refer to that file for the full automated setup including the `docker-netns-mkdir` systemd service.

3. **Clone the repo inside the WSL2 filesystem**

   ```bash
   cd ~
   git clone https://github.com/wdion-arista/ceos-act-projects.git
   cd ceos-act-projects
   git submodule update --init labs/MandE
   ```

   > Clone inside the WSL2 filesystem (`~/`), not on the Windows mount (`/mnt/c/`), for proper file permissions and performance.

4. **Connect VSCode** — install the [WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) extension, open the folder via **Remote - WSL**, then **Reopen in Container**

See also: [cEOS and Containerlab on Windows WSL](https://arista.my.site.com/AristaCommunity/s/article/cEOS-and-Containerlab-on-Windows-WSL) (Arista community)

---

### Linux (native)

The most straightforward setup — Docker runs natively, no VM layer.

1. **Install Docker (Moby)**

   On Debian/Ubuntu, the install steps are the same as the [WSL2 section above](#windows-wsl2--moby) (step 2), or refer to [`scripts/debian/cloud-config.yml`](scripts/debian/cloud-config.yml) for the full automated recipe.

   For other distros, follow the [Docker Engine install docs](https://docs.docker.com/engine/install/).

2. **Install the devcontainer CLI** (optional)

   ```bash
   npm install -g @devcontainers/cli
   ```

3. **Clone and open**

   ```bash
   git clone https://github.com/wdion-arista/ceos-act-projects.git
   cd ceos-act-projects
   git submodule update --init labs/MandE
   ```

   Open in VSCode and **Reopen in Container**, or use `./start` to launch a lab.

---

## The MandE Demo Lab

The **[Media & Entertainment (MandE)](labs/MandE/)** lab is the template and reference deployment. It models a multi-site L3LS-EVPN fabric with ISIS underlay, eBGP EVPN overlay, and EVPN multicast across five sites.

| Group | Role | Platform |
| --- | --- | --- |
| `BLUE_SPINES` / `BLUE_LEAFS` | Blue plane | 7280SR3 |
| `RED_SPINES` / `RED_LEAFS` | Red plane | 7280SR3 |
| `PURPLE_LEAFS` | Access / campus | 720XP |

### Environment variables

Copy the example and fill in your tokens:

```bash
cp .env-example .env
# Edit .env — at minimum set ARISTA_TOKEN and LABPASSPHRASE
```

| Variable | Required | Description |
| --- | --- | --- |
| `ARISTA_TOKEN` | Yes | arista.com profile API key (cEOS image downloads) |
| `LABPASSPHRASE` | Yes | Password for lab user accounts |
| `CE_ACT_APKEY` | No | Arista CE ACT API key |
| `CVAAS_TOKEN_LAB` | No | CVaaS token for lab tenant |
| `CVAAS_TOKEN_PROD` | No | CVaaS token for prod tenant |
| `CVP_TOKEN_LAB` | No | On-prem CVP token |
| `CEOS_ARM_IMAGE` | No | cEOS image version (e.g. `4.36.0F`) |

### Key workflows

Run `make help` inside the lab to see all targets. The most common:

```bash
# Build configs
make prod-build                              # Production configs (all sites)
make clab-build                              # ContainerLab configs
make act-build                               # ACT configs

# ContainerLab (local cEOS)
make containerlab-get-image-arm              # Download cEOS (ARM64 — Apple Silicon)
make containerlab-get-image-amd64            # Download cEOS (AMD64 — Intel/AMD)
make clab-containerlab-build-deploy-avd      # Full workflow: build → deploy → AVD startup configs
make containerlab-destroy                    # Tear down the lab

# Deploy to CVaaS
make prod-deploy-cvaas                       # Deploy production configs to CVaaS

# Validate
make prod-validate                           # Validate production network state
make clab-validate                           # Validate ContainerLab network state
```

For the full workflow reference, see the [MandE README](labs/MandE/README.md).

---

## Adding Your Own Lab

Each lab is an independent git repo under `labs/`. To create a new one:

1. Create a directory under `labs/` (e.g. `labs/my-lab/`)
2. Copy the Makefile from MandE:

   ```bash
   cp labs/MandE/Makefile labs/my-lab/
   ```

3. Add your `sites/` directory with `inventory.yml` and `group_vars/` per site
4. Copy `.env-example` from MandE and fill in your tokens
5. Optionally add a `.devcontainer/` config — copy an existing one from `.devcontainer/` and update the `workspaceFolder` and mount paths

Use [MandE](labs/MandE/) as your starting template.

---

## The `start` Script

The `./start` script is a lab launcher that:

1. Lists all labs under `labs/` and presents an `fzf` picker (falls back to `select` if `fzf` is not installed)
2. Starts (or reuses) the devcontainer for the selected lab
3. Opens VSCode attached to the running container

It handles macOS, OrbStack VMs, and native Linux automatically.

---

## GitHub Actions / CI

The CI pipeline ([`.github/workflows/containers-base-publish.yml`](.github/workflows/containers-base-publish.yml)) builds two image variants:

| Image | Description |
| --- | --- |
| `ghcr.io/wdion-arista/ceos-act-projects/base` | Core tools (Ansible, ContainerLab, yq, gh) |
| `ghcr.io/wdion-arista/ceos-act-projects/base-ai` | Core tools + Claude Code, Codex, Gemini CLI |

Both are built for `linux/amd64` and `linux/arm64` across AVD version variants.

### GitHub Environment setup (for forks / template users)

The `main`-branch publish jobs are gated on a GitHub Environment named `production`. Without it, those jobs will hang waiting for an approval reviewer.

To enable them in your fork or template-derived repo:

1. Go to **Settings → Environments → New environment**
2. Name it `production` (exact match)
3. Optionally add required reviewers, wait timers, or environment secrets — leave empty for unattended builds

Branch builds (any branch other than `main`) and release tagging do not require this environment.
