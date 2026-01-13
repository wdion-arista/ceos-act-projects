#!/usr/bin/env python3
import re
import sys
import argparse

def parse_arguments():
    parser = argparse.ArgumentParser(description="Add custom DNS aliases to /etc/hosts for Containerlab nodes.")
    
    parser.add_argument(
        "--domain", 
        required=True, 
        help="The domain suffix to append (e.g., your-domain.ca)"
    )
    parser.add_argument(
        "--lab", 
        required=True, 
        help="The name of the Containerlab lab (used to identify the node prefix)"
    )
    parser.add_argument(
        "--file", 
        default="/etc/hosts", 
        help="Path to the hosts file (default: /etc/hosts)"
    )
    
    return parser.parse_args()

def update_hosts():
    args = parse_arguments()
    
    # Construct the prefix Containerlab uses: clab-<lab_name>-
    # Note: Containerlab converts lab names to lowercase in the hosts file usually, 
    # but let's stick to the raw prefix and ignore case in regex if needed.
    lab_prefix = f"clab-{args.lab}-"
    
    print(f"Targeting Lab Prefix: {lab_prefix}")
    print(f"Domain: {args.domain}")
    print(f"File: {args.file}")

    try:
        with open(args.file, "r") as f:
            lines = f.readlines()
    except PermissionError:
        print(f"Error: Permission denied writing to {args.file}. Please run with sudo.")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: File {args.file} not found.")
        sys.exit(1)

    new_lines = []
    in_block = False
    modified = False

    # Regex to capture: IP (group 1), Full Clab Name (group 2), Node Name Suffix (group 3), Comment (group 4)
    # This handles both cases where the prefix might be standard case or lowercase
    regex_pattern = r"^([\da-fA-F.:]+)\s+(" + re.escape(lab_prefix) + r"([a-zA-Z0-9-_]+))\s+(#.*)?$"
    regex = re.compile(regex_pattern, re.IGNORECASE)

    for line in lines:
        stripped = line.strip()
        
        # Detect Start/End of CLAB block
        if f"###### CLAB-{args.lab}-START ######" in line:
            in_block = True
            new_lines.append(line)
            continue
        if f"###### CLAB-{args.lab}-END ######" in line:
            in_block = False
            new_lines.append(line)
            continue

        if in_block:
            match = regex.match(stripped)
            if match:
                ip = match.group(1)
                full_clab_name = match.group(2)
                short_node_name = match.group(3) # e.g. SW101-SITE1-B
                comment = match.group(4) if match.group(4) else ""
                
                # Construct custom alias (force lowercase for DNS standards)
                custom_alias = f"{short_node_name.lower()}.{args.domain}"

                # Check if alias is already present to avoid duplicates
                if custom_alias not in line:
                    # Reconstruct line: IP <tab> ClabName <tab> CustomAlias <tab> Comment
                    new_line = f"{ip}\t{full_clab_name}\t{custom_alias}\t{comment}\n"
                    new_lines.append(new_line)
                    modified = True
                    print(f"  [+] Added alias: {custom_alias} -> {ip}")
                    continue
        
        # If not in block or no match, keep line as is
        new_lines.append(line)

    if modified:
        with open(args.file, "w") as f:
            f.writelines(new_lines)
        print(f"Success: {args.file} updated.")
    else:
        print("No changes needed (aliases already exist or lab not found).")

if __name__ == "__main__":
    update_hosts()