#!/bin/bash

# Script to login to Arista EOS, generate and transfer a support bundle
# using the 'send support-bundle' command.
# This script expects password authentication for SSH/SCP connections to EOS.

# --- Configuration ---
# You can pre-configure these or leave them blank to be prompted.
EOS_USER=""
REMOTE_USER=""    # For SCP direct send
REMOTE_SERVER=""  # For SCP direct send
REMOTE_PATH=""    # For SCP direct send (e.g., /tmp/ or support_bundles/)
                  # Must be an existing directory on the remote server.

# "FTP-like" variables are for user convenience in naming.
# The actual transfer for send support-bundle is ALWAYS SSH-based.
FTP_LIKE_USER=""
FTP_LIKE_SERVER=""
FTP_LIKE_PATH=""

# --- Helper Functions ---
ech_info() {
  echo -e "\033[32m[INFO]\033[0m $1"
}

ech_warn() {
  echo -e "\033[33m[WARN]\033[0m $1"
}

ech_error() {
  echo -e "\033[31m[ERROR]\033[0m $1" >&2
  exit 1
}

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local is_password="$3" # "password" or ""
  local current_val="${!var_name}"

  if [ -z "$current_val" ]; then
    if [ "$is_password" == "password" ]; then
      read -rsp "$prompt_text: " "$var_name"
      echo
    else
      read -rp "$prompt_text: " "$var_name"
    fi
    eval "$var_name=\"\${!var_name}\""
  fi
}

display_help() {
    echo
    echo "Arista EOS Support Bundle Assistant"
    echo "-----------------------------------"
    echo "This script connects to an Arista EOS device, uses the 'send support-bundle'"
    echo "command to generate a support bundle, and facilitates its transfer."
    echo "It expects password authentication for operations requiring SSH/SCP to the EOS device."
    echo
    echo "Usage: $0 [-h|--help] [eos_hostname_or_ip]"
    echo
    echo "Arguments & Options:"
    echo "  eos_hostname_or_ip  (Optional) The IP address or hostname of the Arista EOS device."
    echo "                      If this argument is omitted, the script will prompt for it."
    echo
    echo "  -h, --help          Display this help message and exit."
    echo
    echo "Script Workflow:"
    echo "1. Prompts for EOS device IP (if not provided as an argument) and EOS username."
    echo "2. Asks for optional parameters for the 'send support-bundle' command:"
    echo "   - TAC case number (to be included in the bundle filename)."
    echo "   - Option to exclude core files (to reduce bundle size)."
    echo "3. Prompts to choose a transfer method:"
    echo "   - Option 1: Save bundle to EOS flash, then SCP to the local machine."
    echo "   - Option 2: Instruct EOS to send the bundle directly to a remote SCP server."
    echo "   - Option 3: Instruct EOS to send the bundle directly to an 'FTP-like' server"
    echo "                 (Note: This uses SSH for actual transport; the remote server must be an SSH server)."
    echo "4. Executes the chosen action, prompting for passwords as required by SSH/SCP."
    echo
    exit 0
}

# --- Main Script ---

# Check for help option first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    display_help
fi

ech_info "This script uses the 'send support-bundle' command on Arista EOS."
ech_info "You will be prompted for the EOS password by SSH/SCP for various operations."
echo ""

# Get EOS Device Info
# Check if EOS_IP is provided as a command-line argument (and it wasn't -h/--help)
if [ -n "$1" ]; then # $1 exists and wasn't help
  EOS_IP="$1"
  ech_info "Using Arista EOS device IP/hostname from argument: $EOS_IP"
else
  prompt_if_empty "EOS_IP" "Enter Arista EOS device IP or hostname"
fi
prompt_if_empty "EOS_USER" "Enter EOS username"


# SSH Options
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
# For higher security, remove StrictHostKeyChecking=no and UserKnownHostsFile=/dev/null
# and manage known_hosts file properly.

# Build 'send support-bundle' command options
SEND_BUNDLE_CMD_BASE="send support-bundle"
ADDITIONAL_OPTS=""

read -rp "Do you want to specify a case number (e.g., for TAC)? (y/N): " specify_case
if [[ "$specify_case" =~ ^[Yy]$ ]]; then
  prompt_if_empty "CASE_NUMBER" "Enter case number"
  ADDITIONAL_OPTS="$ADDITIONAL_OPTS case-number $CASE_NUMBER"
fi

read -rp "Do you want to exclude core files (can be large)? (y/N): " exclude_cores_choice
if [[ "$exclude_cores_choice" =~ ^[Yy]$ ]]; then
  ADDITIONAL_OPTS="$ADDITIONAL_OPTS exclude cores"
fi

# Choose Transfer Method
echo ""
ech_info "Choose transfer method for the support bundle:"
echo "1. Save to EOS switch flash, then SCP to THIS local machine (pull)"
echo "2. Send directly from EOS switch to a remote SCP server (push)"
echo "3. Send directly from EOS switch to an 'FTP-like' server (uses SSH transport)"
read -rp "Enter your choice (1-3): " TRANSFER_CHOICE

EOS_COMMAND_TO_RUN=""
BUNDLE_FILENAME_ON_SWITCH="" # Used for option 1

case $TRANSFER_CHOICE in
  1)
    # Save to switch flash, then SCP to local machine
    SWITCH_DEST_DIR_FOR_CMD="flash:" # Send to root of flash
    
    EOS_COMMAND_TO_RUN="$SEND_BUNDLE_CMD_BASE $ADDITIONAL_OPTS $SWITCH_DEST_DIR_FOR_CMD"
    
    ech_info "Attempting to generate bundle on $EOS_IP at $SWITCH_DEST_DIR_FOR_CMD..."
    ech_info "(You will be prompted for the $EOS_USER password for $EOS_IP)"
    
    OUTPUT=$(ssh $SSH_OPTS "$EOS_USER@$EOS_IP" "enable
$EOS_COMMAND_TO_RUN
exit")

    echo "$OUTPUT" # Show full output to user

    # Parse output to find filename and destination (robustly)
    SUCCESS_LINE=$(echo "$OUTPUT" | grep 'Support bundle .* successfully sent to')

    if [ -n "$SUCCESS_LINE" ]; then
        BUNDLE_FILENAME_ON_SWITCH=$(echo "$SUCCESS_LINE" | awk '{print $3}')
      
        if [ -z "$BUNDLE_FILENAME_ON_SWITCH" ]; then
            ech_error "Could not parse bundle filename from EOS output though success message found. Check output above."
            exit 1
        fi
        ech_info "Bundle '$BUNDLE_FILENAME_ON_SWITCH' reported as generated on switch."

        prompt_if_empty "LOCAL_DEST_PATH" "Enter local destination path for SCP (e.g., /tmp, default: .)"
        if [ -z "$LOCAL_DEST_PATH" ]; then LOCAL_DEST_PATH="."; fi

        SCP_SOURCE_PATH_PRIMARY="/mnt/flash/$BUNDLE_FILENAME_ON_SWITCH"
        SCP_SOURCE_PATH_FALLBACK="flash:/$BUNDLE_FILENAME_ON_SWITCH"

        ech_info "Attempting to copy '$SCP_SOURCE_PATH_PRIMARY' from $EOS_IP to '$LOCAL_DEST_PATH/$BUNDLE_FILENAME_ON_SWITCH'..."
        ech_info "(You will be prompted for the $EOS_USER password for $EOS_IP again for SCP)"
      
        scp $SSH_OPTS "$EOS_USER@$EOS_IP:$SCP_SOURCE_PATH_PRIMARY" "$LOCAL_DEST_PATH/$BUNDLE_FILENAME_ON_SWITCH"
        SCP_SUCCESS=$?
      
        if [ $SCP_SUCCESS -ne 0 ]; then
            ech_warn "SCP with '$SCP_SOURCE_PATH_PRIMARY' failed. Trying with fallback '$SCP_SOURCE_PATH_FALLBACK'..."
            scp $SSH_OPTS "$EOS_USER@$EOS_IP:$SCP_SOURCE_PATH_FALLBACK" "$LOCAL_DEST_PATH/$BUNDLE_FILENAME_ON_SWITCH"
            SCP_SUCCESS=$?
        fi

        if [ $SCP_SUCCESS -eq 0 ]; then
            ech_info "Support bundle successfully copied to $LOCAL_DEST_PATH/$BUNDLE_FILENAME_ON_SWITCH"
            DELETE_PATH_ON_SWITCH_EOS="flash:/$BUNDLE_FILENAME_ON_SWITCH" # Standard EOS path for delete
            read -rp "Do you want to delete the bundle '$BUNDLE_FILENAME_ON_SWITCH' from $EOS_IP ($DELETE_PATH_ON_SWITCH_EOS)? (y/N): " delete_remote
            if [[ "$delete_remote" =~ ^[Yy]$ ]]; then
                ech_info "Deleting '$DELETE_PATH_ON_SWITCH_EOS' from $EOS_IP..."
                ssh $SSH_OPTS "$EOS_USER@$EOS_IP" "enable
delete $DELETE_PATH_ON_SWITCH_EOS
exit"
                ech_info "Deletion command issued."
            fi
        else
            ech_error "Failed to copy support bundle using SCP to local machine with both path attempts."
            ech_warn "The switch may have reported internal errors during the process. This might have affected file creation/visibility."
            ech_warn "Please check 'show error detail' or similar commands on the switch for more information on any internal errors."
        fi
    else
      if [[ "$OUTPUT" == *"ssh: Could not resolve hostname"* || "$OUTPUT" == *"No such file or directory"* || "$OUTPUT" == *"scp:"* ]]; then
          ech_error "Failed to send/generate support bundle on switch. EOS reported an error. Check output above."
      else
          ech_error "Failed to generate/confirm support bundle on switch. Success message not found. Check output above."
      fi
       ech_warn "The switch may have reported internal errors during the process. This might have affected file creation/visibility."
       ech_warn "Please check 'show error detail' or similar commands on the switch for more information on any internal errors."
    fi
    ;;

  2)
    # Send directly to remote SCP server
    prompt_if_empty "REMOTE_USER" "Enter remote SCP server username"
    prompt_if_empty "REMOTE_SERVER" "Enter remote SCP server IP or hostname"
    prompt_if_empty "REMOTE_PATH" "Enter remote SCP server destination path (e.g., /tmp/support/)"
    ech_warn "The destination path '$REMOTE_PATH' must exist on '$REMOTE_SERVER'."

    REMOTE_URL="scp://$REMOTE_USER@$REMOTE_SERVER/$REMOTE_PATH"
    EOS_COMMAND_TO_RUN="$SEND_BUNDLE_CMD_BASE $ADDITIONAL_OPTS $REMOTE_URL"

    ech_info "Instructing $EOS_IP to send support bundle directly to $REMOTE_URL"
    ech_info "(You will be prompted for the $EOS_USER password for $EOS_IP to issue the command)"
    ech_warn "After connecting to EOS, EOS will prompt for '$REMOTE_USER@$REMOTE_SERVER' password if required by the remote server."
    
    ssh $SSH_OPTS "$EOS_USER@$EOS_IP" "enable
$EOS_COMMAND_TO_RUN
exit"

    ech_info "Command issued. Check the output from $EOS_IP above for status."
    ech_info "If successful, the bundle (e.g., support-bundle-*.zip) should be on $REMOTE_SERVER in $REMOTE_PATH"
    ;;

  3)
    # Send "FTP-like" (actually SSH transport)
    ech_warn "IMPORTANT: 'send support-bundle' always uses SSH for transport."
    ech_warn "Therefore, your 'FTP-like' server MUST be an SSH server, and the credentials are for SSH."
    prompt_if_empty "FTP_LIKE_USER" "Enter username for the remote (SSH) server"
    prompt_if_empty "FTP_LIKE_SERVER" "Enter IP or hostname of the remote (SSH) server"
    prompt_if_empty "FTP_LIKE_PATH" "Enter destination path on the remote (SSH) server (e.g., /uploads/)"
    ech_warn "The destination path '$FTP_LIKE_PATH' must exist on '$FTP_LIKE_SERVER'."

    REMOTE_URL="scp://$FTP_LIKE_USER@$FTP_LIKE_SERVER/$FTP_LIKE_PATH"
    EOS_COMMAND_TO_RUN="$SEND_BUNDLE_CMD_BASE $ADDITIONAL_OPTS $REMOTE_URL"

    ech_info "Instructing $EOS_IP to send support bundle directly to $REMOTE_URL (via SSH)"
    ech_info "(You will be prompted for the $EOS_USER password for $EOS_IP to issue the command)"
    ech_warn "After connecting to EOS, EOS will prompt for '$FTP_LIKE_USER@$FTP_LIKE_SERVER' password if required by that server."

    ssh $SSH_OPTS "$EOS_USER@$EOS_IP" "enable
$EOS_COMMAND_TO_RUN
exit"
    ech_info "Command issued. Check the output from $EOS_IP above for status."
    ech_info "If successful, the bundle should be on $FTP_LIKE_SERVER in $FTP_LIKE_PATH"
    ;;
  *)
    ech_error "Invalid choice. Exiting."
    ;;
esac

ech_info "Script finished."
exit 0