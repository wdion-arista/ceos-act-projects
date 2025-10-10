import copy

# Base template for the desired output structure. All keys are pre-defined.
BASE_PROFILE_TEMPLATE = {
    "parentProfile": None,
    "description": None,
    "enabled": "Yes",
    "mode": None,
    "speed": None,
    "eosCli": None,
    "dot1x": {},
    "flowControl": {},
    "phone": {},
    "poe": {},
    "ptp": {},
    "qosProfile": None,
    "stormControl": {},
    "portChannel": {},
    "spanningTree": {
        "bpduFilter": None,
        "bpduGuard": None,
        "portfast": None
    },
    "vlans": {
        "nativeVlan": None,
        "phoneVlan": None,
        "vlans": None
    }
}

avd_port_mapping = {
    "profile": {"type": "string", "option": "name"},
    "parent_profile": {"type": "string", "option": "parentProfile"},
    "description": {"type": "string", "option": "description"},
    "enabled": {"type": "bool_to_str", "option": "enabled", "true": "Yes", "false": "No"},
    "mode": {"type": "string", "option": "mode"},
    "speed": {"type": "string", "option": "speed"},
    "raw_eos_cli": {"type": "string", "option": "eosCli"},
    "vlans": {"type": "string", "option": ("vlans", "vlans")},
    "native_vlan": {"type": "int", "option": ("vlans", "nativeVlan")},
    "phone_vlan": {"type": "int", "option": ("vlans", "phoneVlan")},
    "spanning_tree_portfast": {"type": "string", "option": ("spanningTree", "portfast")},
    "spanning_tree_bpdufilter": {"type": "bool_to_str", "option": ("spanningTree", "bpduFilter"), "true": "enabled", "false": "disabled"},
    "spanning_tree_bpduguard": {"type": "bool_to_str", "option": ("spanningTree", "bpduGuard"), "true": "enabled", "false": "disabled"},
    "qos_profile": {"type": "string", "option": "qosProfile"},
}

def transform_data(source_data, mapping, template):
    """
    Transforms a dictionary or a list of dictionaries based on a mapping configuration and a template.

    Args:
        source_data (list or dict): The original data to transform.
        mapping (dict): A dictionary defining the transformation rules.
        template (dict): A template dictionary for the base output structure.

    Returns:
        list or dict: The transformed data, matching the input type.
    """

    def set_nested_value(d, path, value):
        """Helper function to set a value in a nested dictionary."""
        if isinstance(path, str):
            d[path] = value
            return
        
        keys = list(path)
        current_level = d
        for key in keys[:-1]:
            current_level = current_level.setdefault(key, {})
        current_level[keys[-1]] = value

    def transform_single_item(item, mapping_rules, base_template):
        """Transforms a single dictionary item using a base template."""
        # Start with a fresh copy of the template to ensure all keys are present
        transformed_item = copy.deepcopy(base_template)

        for source_key, source_value in item.items():
            if source_key not in mapping_rules:
                continue

            rule = mapping_rules[source_key]
            destination_path = rule['option']
            value_type = rule['type']
            final_value = source_value

            # Handle type-specific value conversions
            if value_type == 'bool_to_str':
                if source_value in [True, 'True', 'true', 'enabled']:
                    final_value = rule.get('true', 'enabled2')
                else:
                    final_value = rule.get('false', 'disabled')
            elif value_type == 'string':
                final_value = str(source_value) if source_value is not None else None
            elif value_type == 'int':
                final_value = int(source_value) if source_value is not None else None
            # The 'bool' type is handled implicitly if the source is a true boolean
            elif value_type == 'bool':
                final_value = bool(source_value)

            set_nested_value(transformed_item, destination_path, final_value)
        
        return transformed_item

    # --- Main function logic ---
    if isinstance(source_data, list):
        return [transform_single_item(item, mapping, template) for item in source_data]
    elif isinstance(source_data, dict):
        return transform_single_item(source_data, mapping, template)
    else:
        raise TypeError("Input data must be a dictionary or a list of dictionaries.")
