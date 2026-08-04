---
name: avd-upgrade-6x
description: Migrate an AVD lab from version 5.7.2 to 6.1 — guided checklist for group_vars/global_vars YAML key renames, removals, schema changes, and custom_structured_configuration_ prefix migration.
user_invocable: true
---

# AVD 5.7.2 → 6.1 Migration

Guided checklist for migrating a lab under `labs/` from Arista AVD 5.7.2 to 6.1. The shared infrastructure (common/playbooks, act_topgen templates) is already updated — this skill handles the per-lab group_vars/global_vars changes.

Reference: `labs/MandE/Docs/AVD-5.7.2-to-6.1-Migration.md` for the complete MandE migration with before/after examples.

---

## Step 1: Pre-flight

1. Identify the lab root directory (should contain `Makefile`, `ansible.cfg`, `sites/`).
2. List all YAML files that will need changes:
   ```bash
   find global_vars/ sites/*/group_vars/ -name '*.yml' -o -name '*.yaml' | sort
   ```
3. Confirm the current AVD version:
   ```bash
   ansible-galaxy collection list arista.avd
   ```
   If still on 5.x, install 6.1 first: `ansible-galaxy collection install arista.avd:==6.1.0 --force`
4. Run a baseline build to capture the pre-migration state:
   ```bash
   source .env && make prod-build
   ```
   Save the generated configs for diffing later:
   ```bash
   cp -r sites/*/intended sites/*/intended-pre-migration 2>/dev/null || true
   ```

---

## Step 2: Removed Data Models

Search for and remove these keys. They no longer exist in AVD 6.x.

### `avd_data_validation_mode`
- **Search:** `grep -rn 'avd_data_validation_mode' global_vars/ sites/*/group_vars/`
- **Action:** Delete the entire line (`avd_data_validation_mode: error` or similar).

### `design.type`
- **Search:** `grep -rn 'design:' sites/*/group_vars/ | grep -v custom_structured`
- **Action:** Remove the entire `design:` block (typically `design: type: l3ls-evpn`). AVD 6.x infers design type from node type keys.

---

## Step 3: Renamed Keys

For each rename, search across all group_vars/global_vars files. Apply the rename in-place, preserving the value and indentation.

### `local_users` → `aaa_settings.local_users`
- **Search:** `grep -rn '^local_users:' global_vars/ sites/*/group_vars/`
- **Action:** Wrap the existing `local_users:` list under `aaa_settings:`:
  ```yaml
  # Before
  local_users:
    - name: admin
      ...

  # After
  aaa_settings:
    local_users:
      - name: admin
        ...
  ```

### `underlay_multicast` → `underlay_multicast_pim_sm`
- **Search:** `grep -rn 'underlay_multicast:' sites/*/group_vars/`
- **Action:** Rename the key. Value stays the same (typically `true`).

### `static_routes[]` sub-key renames
- **Search:** `grep -rn 'destination_address_prefix:' sites/*/group_vars/ global_vars/`
- **Action:** Within each `static_routes:` block (inside `structured_config` or `custom_structured_configuration_`):
  - `destination_address_prefix` → `prefix`
  - `gateway` → `next_hop`

### `dhcp_servers[].subnets` → `ipv4_subnets`
- **Search:** `grep -rn 'subnets:' sites/*/group_vars/ | grep -i dhcp`
- **Action:** Rename `subnets:` to `ipv4_subnets:` inside each `dhcp_servers:` block. Check surrounding context to confirm it's inside a DHCP block (not a generic `subnets` key elsewhere).

### `flow_tracking_settings` collector → collectors
- **Search:** `grep -rn 'collector:' sites/*/group_vars/ | grep -v collectors`
- **Action:** Inside `flow_tracking_settings.trackers[].exporters[]`, change the single `collector:` object to a `collectors:` list:
  ```yaml
  # Before
  exporters:
    - name: EXPORTER
      collector:
        host: 127.0.0.1

  # After
  exporters:
    - name: EXPORTER
      collectors:
        - host: 127.0.0.1
  ```

### `radius_server.hosts` → `radius_server.servers`
- **Search:** `grep -rn 'hosts:' sites/*/group_vars/ global_vars/ | grep -i radius`
- **Action:** Under `radius_server:`, rename `hosts:` to `servers:`. The list items stay the same.

### `ip_name_servers` → `ip_name_server` (restructured)
- **Search:** `grep -rn 'ip_name_servers:' sites/*/group_vars/ global_vars/`
- **Action:** Rename the key (plural → singular) AND restructure from a flat list to a VRF-based hierarchy:
  ```yaml
  # Before
  ip_name_servers:
    - ip_address: 8.8.8.8
      vrf: default
    - ip_address: 8.8.8.8
      vrf: Production

  # After
  ip_name_server:
    vrfs:
      - name: default
        servers:
          - ip_address: 8.8.8.8
      - name: Production
        servers:
          - ip_address: 8.8.8.8
  ```

### `ntp.servers[].vrf` → `ntp.vrf`
- **Search:** `grep -rn 'vrf:' sites/*/group_vars/ | grep -B5 ntp`
- **Action:** Move `vrf` from per-server to top-level under `ntp:`:
  ```yaml
  # Before
  ntp:
    servers:
      - name: 1.2.3.4
        vrf: default

  # After
  ntp:
    vrf: default
    servers:
      - name: 1.2.3.4
  ```

---

## Step 4: Removed Sub-Keys

### `router_bgp.peer_groups[].type: evpn`
- **Search:** `grep -rn 'type: evpn' sites/*/group_vars/`
- **Action:** Remove the `type: evpn` line from each `peer_groups:` entry under `structured_config.router_bgp`. Then add explicit settings that `type: evpn` previously auto-configured:
  ```yaml
  peer_groups:
    - name: EVPN-OVERLAY-PEERS
      ebgp_multihop: 3
      maximum_routes: 0
  address_family_evpn:
    peer_groups:
      - name: EVPN-OVERLAY-PEERS
        activate: true
  address_family_ipv4:
    peer_groups:
      - name: EVPN-OVERLAY-PEERS
        activate: false
  ```
  These go inside the same `structured_config.router_bgp` block. Check that `address_family_evpn` and `address_family_ipv4` sections don't already exist — merge if they do.

---

## Step 5: `custom_structured_configuration_` Prefix Migration

This is the largest category. AVD 6.x no longer passes `eos_cli_config_gen` keys through `eos_designs`. Top-level keys in group_vars that are not recognized as `eos_designs` inputs must be prefixed with `custom_structured_configuration_`.

### Known keys that need the prefix

Scan each group_vars/global_vars file for these top-level keys:

| Key | Typical files |
|-----|---------------|
| `management_console` | fabric group_vars |
| `management_ssh` | fabric group_vars |
| `dns_domain` | fabric group_vars |
| `clock` | fabric group_vars |
| `ipv6_unicast_routing` | fabric group_vars |
| `interface_defaults` | fabric group_vars |
| `errdisable` | fabric group_vars |
| `radius_server` | fabric group_vars |
| `aaa_server_groups` | fabric group_vars |
| `aaa_accounting` | fabric group_vars |
| `aaa_authentication` | fabric group_vars |
| `dot1x` | fabric group_vars |
| `static_routes` | fabric, PROD group_vars |
| `ip_dhcp_snooping` | fabric, global_vars |
| `management_api_http` | global_vars |
| `banners` | global_vars |
| `aliases` | global_vars |
| `aaa_authorization` | global_vars |
| `aaa_root` | CLAB/ACT group_vars |
| `daemon_terminattr` | CLAB/ACT group_vars |
| `ntp` | CLAB/ACT group_vars |
| `ip_name_server` | CLAB/ACT group_vars |
| `mpls` | NETWORK_SERVICES group_vars |
| `agents` | ACT group_vars |

### How to apply

For each key found at the top level of a group_vars file (NOT inside `structured_config:`):

```yaml
# Before — top-level key
dns_domain: lab.example.com

# After — prefixed (underscore, not nested dict)
custom_structured_configuration_dns_domain: lab.example.com
```

**Important:** Use the underscore prefix form, NOT a nested dict:
```yaml
# WRONG — dict form is NOT processed by AVD
custom_structured_configuration:
  dns_domain: lab.example.com
```

### Catch stragglers

After applying all known renames, run a build and check for warnings:
```bash
source .env && make prod-build 2>&1 | grep -i 'WARNING\|deprecated\|not recognized'
```
Any remaining unrecognized keys in the warnings also need the `custom_structured_configuration_` prefix.

---

## Step 6: Schema Structure Changes

### `errdisable.recovery.causes` — string list → dict list
- **Search:** `grep -rn 'errdisable:' sites/*/group_vars/ global_vars/`
- **Action:** Convert each cause from a plain string to a dict with `name` and `interval`:
  ```yaml
  # Before
  errdisable:
    recovery:
      causes:
        - bpduguard
        - link-flap
      interval: 30

  # After
  errdisable:
    recovery:
      causes:
        - name: bpduguard
          interval: 30
        - name: link-flap
          interval: 30
  ```
  Remove the shared `interval:` key — it's now per-cause.

### `aaa_accounting.dot1x.default` — flat group → methods list
- **Search:** `grep -rn 'aaa_accounting:' sites/*/group_vars/ global_vars/`
- **Action:**
  ```yaml
  # Before
  aaa_accounting:
    dot1x:
      default:
        type: "start-stop"
        group: server-group-name

  # After
  aaa_accounting:
    dot1x:
      default:
        type: "start-stop"
        methods:
          - method: group
            group: server-group-name
  ```

---

## Step 7: Environment Changes

1. Check if `.env-example` exists. If it has password-related variables, ensure `AVD_PASSWORD_SALT` is listed.
2. If `sha512_password` hashes are used in `local_users`/`aaa_settings.local_users`, verify the hash rounds are appropriate. EOS requires the `$rounds=N$` prefix to be absent (use the default 5000 rounds, or set rounds explicitly and ensure EOS supports it).

---

## Step 8: CLAB / ACT Specifics

### Management interface
- AVD 6.x in digital twin mode forces `Management1` for all vEOS/cEOS nodes.
- **Search:** `grep -rn 'mgmt_interface\|management_interface\|Management0' sites/*/group_vars/`
- **Action:** Remove any `management_interface: Management0` from platform settings. The clab topology generator now handles `eth0` → `Management1` mapping via `interface_mapping.json`.

### ACT management IPs
- If `act_mgmt_ip` values are `192.168.1.x`, consider changing to `192.168.0.x` to match CVP's default management subnet (`192.168.0.5/24`).
- **Search:** `grep -rn 'act_mgmt_ip' sites/*/inventory.yml`

### Platform settings cleanup
- **Search:** `grep -rn 'tcam_profile\|lag_hardware_only' sites/*/group_vars/`
- **Action:** Remove `tcam_profile` and `lag_hardware_only` from ACT-specific platform settings if present (these cause warnings in 6.x).

---

## Step 9: Verification

1. Run the build:
   ```bash
   source .env && make prod-build
   ```
2. Confirm zero Ansible failures:
   ```bash
   # Output should show failed=0 for all hosts
   ```
3. Check for remaining warnings:
   ```bash
   source .env && make prod-build 2>&1 | grep -i 'WARNING\|deprecated'
   ```
4. Diff generated configs against the pre-migration baseline:
   ```bash
   diff -r sites/*/intended-pre-migration/configs sites/*/intended/configs
   ```
   Expected diffs are rendering-only changes:
   - `maximum-paths 4 ecmp 4` → `maximum-paths 4`
   - `errdisable recovery interval 30` → per-cause `errdisable recovery cause X interval 30`
   - Trailing whitespace removal on aliases
5. If clab builds are used: `make clab-build` and verify output.
6. If ACT builds are used: `make act-build` and verify output.
7. Clean up:
   ```bash
   rm -rf sites/*/intended-pre-migration
   ```

---

## Step 10: Documentation

Create a migration document at `Docs/AVD-5.7.2-to-6.1-Migration.md` (or similar) in the lab directory, listing:
- Every file modified and what changed
- Any lab-specific deviations from the standard migration
- Expected rendering diffs in the generated configs
- Use `labs/MandE/Docs/AVD-5.7.2-to-6.1-Migration.md` as a template
