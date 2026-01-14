import yaml
import argparse
import os
import sys

# --- ARGUMENT PARSING ---
def parse_arguments():
    parser = argparse.ArgumentParser(description="Auto-fill dummy interfaces and link to a bridge.")
    
    parser.add_argument(
        "-i", "--input", 
        required=True, 
        help="The input topology YAML file (e.g., MandE-eastcoast.clab.yml)"
    )
    
    parser.add_argument(
        "--bridge", 
        default="br-dummy", 
        help="The name of the bridge node (default: br-dummy)"
    )
    
    parser.add_argument(
        "--ports", 
        type=int, 
        default=48, 
        help="The number of ports to fill per switch (default: 48)"
    )
    
    return parser.parse_args()
# ---------------------

def add_bridge_links():
    args = parse_arguments()
    
    input_file = args.input
    bridge_name = args.bridge
    max_ports = args.ports

    # --- FILENAME LOGIC ---
    if input_file.endswith(".clab.yml"):
        base_name = input_file[:-9]
        extension = ".clab.yml"
    elif input_file.endswith(".yml"):
        base_name = input_file[:-4]
        extension = ".yml"
    elif input_file.endswith(".yaml"):
        base_name = input_file[:-5]
        extension = ".yaml"
    else:
        base_name = input_file
        extension = ""

    output_file = f"{base_name}-full{extension}"
    backup_file = f"{base_name}.clab-org.yml"
    # ----------------------

    try:
        with open(input_file, 'r') as f:
            topo = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: Could not find input file: {input_file}")
        sys.exit(1)

    # Ensure topology structure exists
    if 'topology' not in topo:
        topo['topology'] = {}
    if 'nodes' not in topo['topology']:
        topo['topology']['nodes'] = {}
    if 'links' not in topo['topology']:
        topo['topology']['links'] = []

    nodes = topo['topology']['nodes']
    links = topo['topology']['links']
    
    # --- 0. Add Bridge Node if Missing ---
    if bridge_name not in nodes:
        print(f"Adding missing bridge node '{bridge_name}' to topology...")
        nodes[bridge_name] = {'kind': 'bridge'}

    # 1. Identify used ports to avoid duplicates
    used_ports = {node: set() for node in nodes}
    
    for link in links:
        if 'endpoints' in link:
            for ep in link['endpoints']:
                if ':' in ep:
                    node_name, port_name = ep.split(':', 1)
                    if node_name in used_ports:
                        used_ports[node_name].add(port_name)

    # 2. Generate new links to the bridge
    new_links = []
    print(f"Scanning nodes in {input_file} for missing ports (1-{max_ports})...")
    
    for node_name, node_data in nodes.items():
        # Only process Arista cEOS nodes
        if node_data.get('kind') == 'arista_ceos':
            for i in range(1, max_ports + 1):
                port_name = f"eth{i}"
                
                if port_name not in used_ports[node_name]:
                    bridge_endpoint = f"{bridge_name}:{node_name}-{port_name}"
                    node_endpoint = f"{node_name}:{port_name}"
                    
                    new_links.append({
                        "endpoints": [bridge_endpoint, node_endpoint]
                    })

    # 3. Save Output and Rename Original
    # We save even if no new links were added, because we might have added the bridge node.
    if new_links or (bridge_name in nodes):
        if new_links:
            count = len(new_links)
            print(f"Generated {count} new connections to {bridge_name}.")
            links.extend(new_links)
        
        # Write the new "full" file
        with open(output_file, 'w') as f:
            yaml.dump(topo, f, sort_keys=False)
        print(f"New topology saved to: {output_file}")
        
        # Rename the original input file to the backup name
        print(f"Renaming original input to: {backup_file}")
        os.rename(input_file, backup_file)
        
    else:
        print("No changes needed.")

if __name__ == "__main__":
    add_bridge_links()