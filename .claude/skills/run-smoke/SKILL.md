---
name: run-smoke
description: Build, run, and smoke-test the MandE AVD lab — run make prod-build/clab-build/act-build, verify output, check for secrets. Use when asked to run, build, test, or verify the MandE lab.
user_invocable: true
---

# Run MandE AVD Lab

The MandE lab is an Ansible/AVD infrastructure project that generates EOS device configurations. There is no GUI or server — the "app" is `make` targets that run Ansible playbooks producing config files.

The driver is `.claude/skills/run-smoke/smoke.sh` — it builds configs, verifies output counts, and checks source files for leaked secrets.

## Prerequisites

- `ansible-playbook` on PATH
- `arista.avd` collection installed (`ansible-galaxy collection list arista.avd`)
- `.env` file with at least `LABPASSPHRASE` set (copy from `.env-example`)

## Run (agent path)

```bash
# Build and verify PROD configs (~8s)
.claude/skills/run-smoke/smoke.sh prod

# Build and verify CLAB configs
.claude/skills/run-smoke/smoke.sh clab

# Build and verify ACT configs
.claude/skills/run-smoke/smoke.sh act

# Run all three
.claude/skills/run-smoke/smoke.sh all

# Single site
SITES="sites/eastcoast/" .claude/skills/run-smoke/smoke.sh prod
```

Exit code 0 = all checks passed. Non-zero = check the output for red lines.

## Run (human path)

```bash
source .env
make prod-build                        # PROD configs
make clab-build                        # ContainerLab configs
make act-build                         # ACT configs
SITES="sites/eastcoast/" make prod-build  # Single site
```

Generated output lands in (all gitignored):
- `sites/eastcoast/intended/configs/` — EOS CLI configs
- `sites/eastcoast/intended/structured_configs/` — YAML structured data
- `sites/eastcoast/documentation/` — topology docs (tracked)
- `sites/eastcoast/clab/intended/` — containerlab configs
- `sites/eastcoast/act/` — ACT topology

## What the smoke test checks

1. Environment: `.env` exists, `LABPASSPHRASE` set, `ansible-playbook` + `arista.avd` present
2. Build: runs the make target, checks Ansible exits with 0 failures
3. Output: verifies expected file counts (11 configs, 11 structured configs, docs)
4. Secrets: greps source files (group_vars, global_vars, inventory) for the `LABPASSPHRASE` value — catches accidental hardcoding

## Gotchas

- **Builds are idempotent**: running twice produces `changed=0` on the second run. The smoke test handles both cases.
- **`intended/`, `clab/`, `act/` are gitignored**: generated output exists locally but is never committed. This is intentional.
- **SHA-512 rounds must be 5000**: EOS rejects hashes with non-default rounds (the `$rounds=N$` prefix in the hash string is not supported).
- **The `.env` must be sourced**: the Makefile sources it internally, but if you run `ansible-playbook` directly you need `source .env` first.
