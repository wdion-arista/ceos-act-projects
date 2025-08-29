#!/bin/bash

# Get the username from your macOS host.
# This variable will be used to create a user with the same name inside the VM.
HOST_USERNAME=$(whoami)

# Define your public SSH key here.
# IMPORTANT: Replace this with your actual SSH public key content (e.g., from ~/.ssh/id_rsa.pub).
# This is crucial for logging into the VM.
PUBLIC_SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)

# --- Define the output file name ---
OUTPUT_FILE="cloud-config.yml"
# --- User Arguments ---
USER_INPUT_CPU="$1"
USER_INPUT_MEMORY="$2"

# --- Define Desired CPU ---
# If USER_INPUT_CPU is provided, use it; otherwise, default to 8.
if [[ -n "$USER_INPUT_CPU" ]]; then
    DESIRED_CPU="$USER_INPUT_CPU"
else
    DESIRED_CPU="8" # Default CPU if not provided
fi

# --- Define Desired Memory in MiB ---
# If USER_INPUT_MEMORY is provided, multiply it by 102 to get MiB; otherwise, default to 24 (MB).
# Using integer arithmetic for multiplication.
if [[ -n "$USER_INPUT_MEMORY" ]]; then
    DESIRED_MEMORY_MIB=$(( USER_INPUT_MEMORY * 1024 ))
    echo "Calculated DESIRED_MEMORY_MIB: ${USER_INPUT_MEMORY} * 1024 = ${DESIRED_MEMORY_MIB} MiB"
else
    DESIRED_MEMORY_MIB="24576" # Default 24MB (MiB) if not provided
fi

# --- Function to handle errors ---
handle_error() {
    echo "ERROR: An error occurred on line $1. Exiting."
    exit 1
}

# --- Function to check and set OrbStack configuration ---
check_orb_config() {
    echo "--- Checking OrbStack Configuration (if OrbStack is installed) ---"

    # Disable error trapping temporarily for orb commands to allow controlled error handling
    trap - ERR

    if command -v orb &> /dev/null; then
        echo "OrbStack 'orb' command found. Checking configuration..."
        # Capture stderr as well for better error messages from orb commands
        ORB_CONFIG_OUTPUT=$(orb config show 2>&1)

        if [ $? -eq 0 ]; then
            # Use the dynamically determined DESIRED_CPU and DESIRED_MEMORY_MIB
            local_DESIRED_CPU="${DESIRED_CPU}"
            local_DESIRED_MEMORY_MIB="${DESIRED_MEMORY_MIB}"

            CPU_SETTING=$(echo "${ORB_CONFIG_OUTPUT}" | grep '^cpu:' | awk '{print $2}')
            MEMORY_SETTING=$(echo "${ORB_CONFIG_OUTPUT}" | grep '^memory_mib:' | awk '{print $2}')

            echo "Current OrbStack CPU setting: ${CPU_SETTING:-Not found}"
            echo "Current OrbStack Memory (MiB) setting: ${MEMORY_SETTING:-Not found}"
            echo "Desired OrbStack CPU setting: ${local_DESIRED_CPU}"
            echo "Desired OrbStack Memory (MiB) setting: ${local_DESIRED_MEMORY_MIB}"


            CPU_NEEDS_SET=false
            MEMORY_NEEDS_SET=false

            if [ "${CPU_SETTING}" != "${local_DESIRED_CPU}" ]; then
                echo "❌ OrbStack CPU is NOT set to ${local_DESIRED_CPU}. Current: '${CPU_SETTING}'"
                CPU_NEEDS_SET=true
            else
                echo "✅ OrbStack CPU is set to ${local_DESIRED_CPU}."
            fi

            if [ "${MEMORY_SETTING}" != "${local_DESIRED_MEMORY_MIB}" ]; then
                echo "❌ OrbStack Memory (MiB) is NOT set to ${local_DESIRED_MEMORY_MIB}. Current: '${MEMORY_SETTING}'"
                MEMORY_NEEDS_SET=true
            else
                echo "✅ OrbStack Memory (MiB) is set to ${local_DESIRED_MEMORY_MIB}."
            fi

            # --- Apply corrections if needed ---
            if ${CPU_NEEDS_SET} || ${MEMORY_NEEDS_SET}; then
                echo "Attempting to correct OrbStack configuration..."

                if ${CPU_NEEDS_SET}; then
                    echo "Setting OrbStack CPU to ${local_DESIRED_CPU}..."
                    if orb set cpu "${local_DESIRED_CPU}" 2>&1; then # Capture output for better logging
                        echo "Successfully set CPU to ${local_DESIRED_CPU}."
                    else
                        echo "Failed to set CPU to ${local_DESIRED_CPU}. Please check permissions or run with sudo."
                    fi
                fi

                if ${MEMORY_NEEDS_SET}; then
                    echo "Setting OrbStack Memory to ${local_DESIRED_MEMORY_MIB}MiB..."
                    # 'orb set memory' can typically take values like '8GB' or '8192MiB'
                    # Using the MiB value with 'MiB' suffix for clarity and precision.
                    if orb config set memory_mib "${local_DESIRED_MEMORY_MIB}" 2>&1; then # Capture output for better logging
                        echo "Successfully set Memory to ${local_DESIRED_MEMORY_MIB}MiB."
                    else
                        echo "Failed to set Memory to ${local_DESIRED_MEMORY_MIB}MiB. Please check permissions or run with sudo."
                    fi
                fi
                echo "OrbStack configuration update attempt complete. A restart of OrbStack might be required for changes to take full effect."
                echo "You might need to run: orb stop && orb start"
            else
                echo "✨ All desired OrbStack configurations are already met."
            fi

        else
            echo "❌ Failed to get OrbStack configuration. 'orb config show' command failed."
            echo "Error output: ${ORB_CONFIG_OUTPUT}"
        fi
    else
        echo "OrbStack 'orb' command not found. Skipping OrbStack configuration check and correction."
        echo "If OrbStack is installed, ensure 'orb' is in your PATH and you have necessary permissions."
    fi
    echo "-----------------------------------------------------------------"

    # Re-enable error trap after orb checks
    trap 'handle_error ${LINENO}' ERR
}

# --- Generate the cloud-config.yml file ---
echo "Generating ${OUTPUT_FILE}..."
# Create the cloud-init file dynamically using a here-document.
# The content between the first 'EOF' and the last 'EOF' will be written to file.
cat <<EOF > "${OUTPUT_FILE}"
## template: jinja
#cloud-config

write_files:
  # Systemd service to fix missing /run/docker/netns directory for Moby
  - path: /etc/systemd/system/docker-netns-mkdir.service
    permissions: '0644' # Standard permissions for systemd service files
    owner: root:root
    content: |
      [Unit]
      Description=Create /run/docker/netns directory
      After=network.target docker.service

      [Service]
      Type=oneshot
      ExecStart=/usr/bin/mkdir -p /run/docker/netns
      ExecStartPost=/usr/bin/chown root:docker /run/docker/netns
      ExecStartPost=/usr/bin/chmod 755 /run/docker/netns

      [Install]
      WantedBy=multi-user.target

runcmd:
  - echo "Waiting a bit for initial system updates to clear..."
  - sleep 10 # Wait 30 seconds
  # Now install all your packages
  - apt-get install -y openssh-server ca-certificates curl gnupg lsb-release apt-utils

  # Add Microsoft GPG key (needed for Moby repo)
  - curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/microsoft.gpg > /dev/null

  # Add moby APT repo
  - echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" | tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null

  # Explicit apt-get update with retry logic to account for APT locks
  - |
    # Loop to wait for apt lock
    for i in \$(seq 1 10); do
      if apt-get update; then # sudo is implied for runcmd, but explicit is safer for scripts
        echo "apt-get update successful on attempt \$i"
        break
      else
        echo "apt-get update failed on attempt \$i, retrying in 5 seconds..."
        sleep 5
      fi
    done
    # Add error handling if loop exhausts all attempts
    if [ \$i -eq 10 ]; then
      echo "ERROR: apt-get update failed after multiple retries."
      exit 1 # Exit with an error code to signal failure to cloud-init
    fi

  - echo "Starting Moby Docker installation and configuration..."
  
  - groupadd -g 2020 docker

  # Enable ADD_EXTRA_GROUPS if it's commented out or set to 0
  - |
    if grep -qE '^#?ADD_EXTRA_GROUPS=0$' /etc/adduser.conf; then
      sed -i 's/^#*ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/' /etc/adduser.conf
    else
      if ! grep -qE '^ADD_EXTRA_GROUPS=1$' /etc/adduser.conf; then
        echo "ADD_EXTRA_GROUPS=1" >> /etc/adduser.conf
      fi
    fi

  # Append 'docker' to EXTRA_GROUPS if it's not already present
  - |
    if grep -qE '^#?EXTRA_GROUPS=' /etc/adduser.conf; then
      sed -i '/^#*EXTRA_GROUPS=/ s/"$/ docker"/' /etc/adduser.conf
      sed -i 's/^#*EXTRA_GROUPS="/EXTRA_GROUPS="/' /etc/adduser.conf # Ensure it's uncommented
    else
      echo 'EXTRA_GROUPS="docker"' >> /etc/adduser.conf
    fi

  # And then the Moby packages:
  - apt-get install -y moby-engine moby-cli moby-buildx moby-compose nano

  # Add a small delay before interacting with systemd services directly
  - echo "Delaying for systemd to fully initialize..."
  - sleep 10 # Give systemd a few more seconds

  # Systemd daemon-reload and enable/start the new service for netns fix
  - systemctl daemon-reload
  - systemctl enable docker-netns-mkdir.service
  - systemctl start docker-netns-mkdir.service

  # Explicitly enable and start Docker services after a delay
  # This avoids the deb-systemd-invoke issue if systemd wasn't fully ready
  - echo "Enabling and starting Docker services..."
  - systemctl enable docker.service
  - systemctl start docker.service

EOF
# The closing EOF MUST be on a line by itself, with no leading/trailing whitespace.
echo ""
echo "Generated cloud-init file: ${OUTPUT_FILE}"
echo ""
echo "Now you can create your OrbStack machine:"
echo "⭐ orb create -a arm64 debian debian --user-data ${OUTPUT_FILE}"
echo "Then SSH in using:"
echo "⭐ ssh orb"
echo "You might need to add yourself to the docker group when you login the first time:"
echo "⭐ sudo usermod -aG docker $USER"
echo ""

# --- Execute the OrbStack configuration check and correction ---
check_orb_config
