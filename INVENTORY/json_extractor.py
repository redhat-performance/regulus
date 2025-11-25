#!/usr/bin/env python3
"""
JSON Configuration Extractor
Extracts and queries values from environment and lab inventory JSON files
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional


class JSONExtractor:
    """Extract and query values from JSON configuration files"""
    
    def __init__(self, env_file: str, inventory_file: Optional[str] = None):
        self.env_data = self._load_json(env_file)
        self.inventory_data = self._load_json(inventory_file) if inventory_file else {}
        
    def _load_json(self, file_path: str) -> Dict:
        """Load JSON file and return parsed data"""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Error: File '{file_path}' not found", file=sys.stderr)
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in '{file_path}': {e}", file=sys.stderr)
            sys.exit(1)
    
    def get_value(self, key: str, source: str = "env") -> Any:
        """Get a specific value by key from environment or inventory"""
        data = self.env_data if source == "env" else self.inventory_data
        return data.get(key)
    
    def get_nested_value(self, path: str, source: str = "env") -> Any:
        """Get nested value using dot notation (e.g., 'hosts.worker1.ip')"""
        data = self.env_data if source == "env" else self.inventory_data
        keys = path.split('.')
        
        for key in keys:
            if isinstance(data, dict):
                data = data.get(key)
            else:
                return None
        return data
    
    def search_keys(self, pattern: str, source: str = "env") -> Dict:
        """Search for keys containing a pattern"""
        data = self.env_data if source == "env" else self.inventory_data
        results = {}
        
        for key, value in data.items():
            if pattern.lower() in key.lower():
                results[key] = value
        
        return results
    
    def get_all_hosts(self) -> List[str]:
        """Extract all unique hostnames from environment"""
        hosts = set()
        
        # Extract from environment variables
        for key, value in self.env_data.items():
            if 'HOST' in key.upper() and isinstance(value, str):
                # Handle comma-separated hosts
                if ',' in value:
                    hosts.update([h.strip() for h in value.split(',')])
                else:
                    hosts.add(value)
        
        return sorted(list(hosts))
    
    def get_network_config(self) -> Dict:
        """Extract all network-related configuration"""
        network_config = {}
        network_keywords = ['NIC', 'MTU', 'INTERFACE', 'MACVLAN', 'SRIOV', 'DPDK', 'OVN']
        
        for key, value in self.env_data.items():
            if any(keyword in key.upper() for keyword in network_keywords):
                network_config[key] = value
        
        return network_config
    
    def export_bash(self, output_file: str = None):
        """Export environment variables in bash format"""
        lines = []
        for key, value in self.env_data.items():
            if isinstance(value, str):
                lines.append(f'export {key}="{value}"')
            else:
                lines.append(f'export {key}={json.dumps(value)}')
        
        content = '\n'.join(lines)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write(content + '\n')
            print(f"Exported to {output_file}")
        else:
            print(content)
    
    def display_summary(self):
        """Display a summary of the configuration"""
        print("=" * 70)
        print("CONFIGURATION SUMMARY")
        print("=" * 70)
        
        print(f"\nKubeconfig: {self.env_data.get('KUBECONFIG', 'N/A')}")
        
        print(f"\n--- Hosts ---")
        hosts = self.get_all_hosts()
        for host in hosts:
            print(f"  • {host}")
        
        print(f"\n--- Network Configuration ---")
        network = self.get_network_config()
        
        # Group by network type
        sriov = {k: v for k, v in network.items() if 'SRIOV' in k}
        macvlan = {k: v for k, v in network.items() if 'MACVLAN' in k}
        dpdk = {k: v for k, v in network.items() if 'DPDK' in k}
        ovn = {k: v for k, v in network.items() if 'OVN' in k}
        
        if sriov:
            print("\n  SR-IOV:")
            for k, v in sriov.items():
                print(f"    {k}: {v}")
        
        if macvlan:
            print("\n  MACVLAN:")
            for k, v in macvlan.items():
                print(f"    {k}: {v}")
        
        if dpdk:
            print("\n  DPDK:")
            for k, v in dpdk.items():
                print(f"    {k}: {v}")
        
        if ovn:
            print("\n  OVN:")
            for k, v in ovn.items():
                print(f"    {k}: {v}")
        
        print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description='Extract and query values from JSON configuration files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Display summary
  %(prog)s -e env.json --summary
  
  # Get specific value
  %(prog)s -e env.json -k KUBECONFIG
  
  # Search for keys
  %(prog)s -e env.json -s SRIOV
  
  # Export to bash
  %(prog)s -e env.json --export-bash env_vars.sh
  
  # Get all hosts
  %(prog)s -e env.json --hosts
        """
    )
    
    parser.add_argument('-e', '--env', required=True,
                        help='Path to environment JSON file')
    parser.add_argument('-i', '--inventory',
                        help='Path to lab inventory JSON file')
    parser.add_argument('-k', '--key',
                        help='Get value for specific key')
    parser.add_argument('-p', '--path',
                        help='Get nested value using dot notation (e.g., hosts.worker1.ip)')
    parser.add_argument('-s', '--search',
                        help='Search for keys containing pattern')
    parser.add_argument('--summary', action='store_true',
                        help='Display configuration summary')
    parser.add_argument('--hosts', action='store_true',
                        help='List all hosts')
    parser.add_argument('--network', action='store_true',
                        help='Show network configuration')
    parser.add_argument('--export-bash', metavar='FILE',
                        help='Export as bash variables to file')
    parser.add_argument('--json-output', action='store_true',
                        help='Output results as JSON')
    
    args = parser.parse_args()
    
    # Create extractor
    extractor = JSONExtractor(args.env, args.inventory)
    
    # Handle different operations
    if args.summary:
        extractor.display_summary()
    
    elif args.key:
        value = extractor.get_value(args.key)
        if args.json_output:
            print(json.dumps({args.key: value}, indent=2))
        else:
            print(value if value is not None else f"Key '{args.key}' not found")
    
    elif args.path:
        value = extractor.get_nested_value(args.path)
        if args.json_output:
            print(json.dumps({args.path: value}, indent=2))
        else:
            print(value if value is not None else f"Path '{args.path}' not found")
    
    elif args.search:
        results = extractor.search_keys(args.search)
        if args.json_output:
            print(json.dumps(results, indent=2))
        else:
            if results:
                for key, value in results.items():
                    print(f"{key}: {value}")
            else:
                print(f"No keys found matching '{args.search}'")
    
    elif args.hosts:
        hosts = extractor.get_all_hosts()
        if args.json_output:
            print(json.dumps({"hosts": hosts}, indent=2))
        else:
            for host in hosts:
                print(host)
    
    elif args.network:
        network = extractor.get_network_config()
        if args.json_output:
            print(json.dumps(network, indent=2))
        else:
            for key, value in network.items():
                print(f"{key}: {value}")
    
    elif args.export_bash:
        extractor.export_bash(args.export_bash)
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

