#!/bin/bash

# --- Configuration ---
ORB_VM_IP=$(orb ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)
DOCKER_CIDR="172.20.20.0/24"
DOCKER_NET="172.20.20.0"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "--- Checking Network Status ---"

# 1. Improved Route Check
# 'route get' returns a non-zero exit code if the route is not found
if route get "$DOCKER_NET" >/dev/null 2>&1; then
    echo -e "Route to $DOCKER_CIDR: ${GREEN}FOUND${NC}"
    echo "No action needed."
else
    echo -e "Route to $DOCKER_CIDR: ${RED}NOT FOUND${NC}"
    echo "Adding route via $ORB_VM_IP..."
    sudo route -n add -net "$DOCKER_CIDR" "$ORB_VM_IP"
fi

# 2. Check pfctl (Firewall) status
# We check if 'Enabled' is present in the status output
if sudo pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
    echo -e "Firewall (pfctl): ${RED}ENABLED${NC}"
    echo "Disabling firewall..."
    sudo pfctl -d
else
    echo -e "Firewall (pfctl): ${GREEN}DISABLED${NC}"
    echo "No action needed."
fi

echo "--- Setup Complete ---"