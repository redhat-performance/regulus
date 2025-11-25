#!/usr/bin/env python3
"""
Lab Configuration and Testbed Inventory Extractor
Extracts and correlates information from env.json and testbed.json files

Usage:
    # Show combined summary
    ./lab_extractor.py --env env.json --testbed testbed.json --summary
    
    # Get host details
    ./lab_extractor.py --env env.json --testbed testbed.json --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com
    
    # List all NICs with their models
    ./lab_extractor.py --env env.json --testbed testbed.json --list-nics
    
    # Export environment variables
    ./lab_extractor.py --env env.json --export-bash env_vars.sh
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional
from collections import defaultdict


class LabExtractor:
    """Extract and correlate lab configuration and hardware inventory"""
    
    def __init__(self, env_file: str, testbed_file: Optional[str] = None):
        self.env_data = self._load_json(env_file)
        self.testbed_data = self._load_json(testbed_file) if testbed_file else {}
        
        # Build lookup tables
        self.worker_hosts = self._extract_worker_hosts()
        self.external_hosts = self._extract_external_hosts()
        self.all_hosts = self._extract_all_hosts()
        
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
    
    def _extract_worker_hosts(self) -> List[str]:
        """Extract OCP worker hostnames from env"""
        workers = []
        for key, value in self.env_data.items():
            if key.startswith("OCP_WORKER_") and isinstance(value, str):
                if value not in workers:
                    workers.append(value)
        return workers
    
    def _extract_external_hosts(self) -> Dict[str, List[str]]:
        """Extract external hosts (BM_HOSTS, TREX_HOSTS) with their roles"""
        external = defaultdict(list)
        
        # BM_HOSTS
        bm_hosts = self.env_data.get("BM_HOSTS", "")
        if bm_hosts:
            for host in bm_hosts.split():
                host = host.strip()
                if host:
                    external[host].append("bm_host")
        
        # TREX_HOSTS
        trex_hosts = self.env_data.get("TREX_HOSTS", "")
        if trex_hosts:
            for host in trex_hosts.split():
                host = host.strip()
                if host:
                    if "trex_host" not in external[host]:
                        external[host].append("trex_host")
        
        # REG_OCPHOST
        ocp_host = self.env_data.get("REG_OCPHOST", "")
        if ocp_host:
            if "registry" not in external[ocp_host]:
                external[ocp_host].append("registry")
        
        return dict(external)
    
    def _extract_all_hosts(self) -> List[str]:
        """Extract all unique hostnames"""
        hosts = set()
        
        # Add workers
        hosts.update(self.worker_hosts)
        
        # Add external hosts
        hosts.update(self.external_hosts.keys())
        
        return sorted(list(hosts))
    
    def get_env_value(self, key: str) -> Any:
        """Get a specific value from environment"""
        return self.env_data.get(key)
    
    def search_env(self, pattern: str) -> Dict:
        """Search for keys containing a pattern in environment"""
        results = {}
        for key, value in self.env_data.items():
            if pattern.lower() in key.lower():
                results[key] = value
        return results
    
    def get_host_config(self, hostname: str) -> Dict:
        """Get complete configuration for a specific host"""
        config = {
            "hostname": hostname,
            "roles": [],
            "env_config": {},
            "hardware": None
        }
        
        # Determine roles
        if hostname in self.worker_hosts:
            config["roles"].append("ocp_worker")
            worker_idx = self.worker_hosts.index(hostname)
            config["env_config"]["worker_index"] = worker_idx
        
        if hostname in self.external_hosts:
            config["roles"].extend(self.external_hosts[hostname])
        
        # Extract relevant env config
        if "ocp_worker" in config["roles"]:
            config["env_config"]["ssh_user"] = "core"
        elif "bm_host" in config["roles"] or "trex_host" in config["roles"]:
            config["env_config"]["ssh_user"] = "root"
        
        # Get hardware info from testbed if available
        if self.testbed_data:
            # Check in different testbed sections
            if "ocp_workers_details" in self.testbed_data:
                if hostname in self.testbed_data["ocp_workers_details"]:
                    config["hardware"] = self.testbed_data["ocp_workers_details"][hostname]
            
            if "external_servers" in self.testbed_data:
                if hostname in self.testbed_data["external_servers"]:
                    config["hardware"] = self.testbed_data["external_servers"][hostname]
            
            # Fallback to flat nodes structure
            if not config["hardware"] and "nodes" in self.testbed_data:
                if hostname in self.testbed_data["nodes"]:
                    config["hardware"] = self.testbed_data["nodes"][hostname]
        
        return config
    
    def get_network_config(self) -> Dict:
        """Extract all network-related configuration"""
        network = {}
        
        # SR-IOV
        network["sriov"] = {
            "nic": self.env_data.get("REG_SRIOV_NIC"),
            "mtu": self.env_data.get("REG_SRIOV_MTU"),
            "model": self.env_data.get("REG_SRIOV_NIC_MODEL")
        }
        
        # MACVLAN
        network["macvlan"] = {
            "nic": self.env_data.get("REG_MACVLAN_NIC"),
            "mtu": self.env_data.get("REG_MACVLAN_MTU"),
            "model": self.env_data.get("REG_MACVLAN_NIC_MODEL")
        }
        
        # DPDK
        network["dpdk"] = {
            "nic_1": self.env_data.get("REG_DPDK_NIC_1"),
            "nic_2": self.env_data.get("REG_DPDK_NIC_2"),
            "model": self.env_data.get("REG_DPDK_NIC_MODEL"),
            "remote_config": self.env_data.get("REM_DPDK_CONFIG")
        }
        
        # TRex
        network["trex"] = {
            "hosts": self.env_data.get("TREX_HOSTS"),
            "interface_1": self.env_data.get("TREX_SRIOV_INTERFACE_1"),
            "interface_2": self.env_data.get("TREX_SRIOV_INTERFACE_2"),
            "model": self.env_data.get("TREX_DPDK_NIC_MODEL")
        }
        
        # OVN
        network["ovn"] = {
            "nic": self.env_data.get("REG_OVN_NIC"),
            "model": self.env_data.get("REG_OVN_NIC_MODEL"),
            "mtu": self.env_data.get("REG_OVN_NIC_MTU")
        }
        
        return network
    
    def list_nics_with_models(self) -> List[Dict]:
        """List all NICs with their models from both env and hardware inventory"""
        nics = []
        
        # From environment configuration
        network = self.get_network_config()
        
        for net_type, config in network.items():
            if isinstance(config, dict):
                if "nic" in config and config["nic"]:
                    nics.append({
                        "interface": config["nic"],
                        "type": net_type,
                        "model": config.get("model", "Unknown"),
                        "mtu": config.get("mtu"),
                        "source": "env_config"
                    })
                if "nic_1" in config and config["nic_1"]:
                    nics.append({
                        "interface": config["nic_1"],
                        "type": f"{net_type}_1",
                        "model": config.get("model", "Unknown"),
                        "source": "env_config"
                    })
                if "nic_2" in config and config["nic_2"]:
                    nics.append({
                        "interface": config["nic_2"],
                        "type": f"{net_type}_2",
                        "model": config.get("model", "Unknown"),
                        "source": "env_config"
                    })
        
        # From hardware inventory
        if self.testbed_data:
            for section in ["ocp_workers_details", "external_servers", "nodes"]:
                if section in self.testbed_data:
                    hosts_data = self.testbed_data[section]
                    if isinstance(hosts_data, dict):
                        for hostname, host_data in hosts_data.items():
                            if "network" in host_data and "pci_devices" in host_data["network"]:
                                for pci_dev in host_data["network"]["pci_devices"]:
                                    nics.append({
                                        "hostname": hostname,
                                        "pci_device": pci_dev,
                                        "source": "hardware_inventory"
                                    })
        
        return nics
    
    def export_bash(self, output_file: str = None):
        """Export environment variables in bash format"""
        lines = ["#!/bin/bash", "# Exported from env.json", ""]
        
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
        """Display a comprehensive summary"""
        print("=" * 80)
        print("LAB CONFIGURATION SUMMARY")
        print("=" * 80)
        
        # Environment info
        print(f"\n{'-'*80}")
        print("ENVIRONMENT CONFIGURATION")
        print(f"{'-'*80}")
        print(f"Kubeconfig: {self.env_data.get('KUBECONFIG', 'N/A')}")
        print(f"Registry Host: {self.env_data.get('REG_OCPHOST', 'N/A')}")
        
        # Worker nodes
        print(f"\n{'-'*80}")
        print(f"OCP WORKER NODES ({len(self.worker_hosts)})")
        print(f"{'-'*80}")
        for idx, worker in enumerate(self.worker_hosts):
            config = self.get_host_config(worker)
            cpu_info = "N/A"
            if config["hardware"] and "cpu" in config["hardware"]:
                cpu = config["hardware"]["cpu"]
                cpu_model = cpu.get("Model name", "Unknown")
                cpu_count = cpu.get("CPU(s)", "Unknown")
                cpu_info = f"{cpu_model} ({cpu_count} CPUs)"
            
            print(f"  [{idx}] {worker}")
            print(f"      CPU: {cpu_info}")
        
        # External hosts
        if self.external_hosts:
            print(f"\n{'-'*80}")
            print(f"EXTERNAL HOSTS ({len(self.external_hosts)})")
            print(f"{'-'*80}")
            for host, roles in self.external_hosts.items():
                config = self.get_host_config(host)
                print(f"  {host}")
                print(f"      Roles: {', '.join(roles)}")
                
                if config["hardware"] and "cpu" in config["hardware"]:
                    cpu = config["hardware"]["cpu"]
                    cpu_model = cpu.get("Model name", "Unknown")
                    print(f"      CPU: {cpu_model}")
        
        # Network configuration
        print(f"\n{'-'*80}")
        print("NETWORK CONFIGURATION")
        print(f"{'-'*80}")
        network = self.get_network_config()
        
        for net_type, config in network.items():
            if isinstance(config, dict) and any(v for v in config.values() if v):
                print(f"\n  {net_type.upper()}:")
                for key, value in config.items():
                    if value:
                        print(f"    {key}: {value}")
        
        # Testbed statistics
        if self.testbed_data:
            print(f"\n{'-'*80}")
            print("HARDWARE INVENTORY STATISTICS")
            print(f"{'-'*80}")
            
            if "collection_time" in self.testbed_data:
                print(f"Collection Time: {self.testbed_data['collection_time']}")
            
            stats = []
            if "ocp_worker_count" in self.testbed_data:
                stats.append(f"OCP Workers: {self.testbed_data['ocp_worker_count']}")
            if "bm_host_count" in self.testbed_data:
                stats.append(f"BM Hosts: {self.testbed_data['bm_host_count']}")
            if "trex_host_count" in self.testbed_data:
                stats.append(f"TRex Hosts: {self.testbed_data['trex_host_count']}")
            if "control_plane_count" in self.testbed_data:
                stats.append(f"Control Plane: {self.testbed_data['control_plane_count']}")
            
            if stats:
                print(", ".join(stats))
        
        print("\n" + "=" * 80)
    
    def display_host_details(self, hostname: str):
        """Display detailed information for a specific host"""
        config = self.get_host_config(hostname)
        
        print("=" * 80)
        print(f"HOST DETAILS: {hostname}")
        print("=" * 80)
        
        print(f"\nRoles: {', '.join(config['roles']) if config['roles'] else 'Unknown'}")
        
        if config['env_config']:
            print(f"\nEnvironment Configuration:")
            for key, value in config['env_config'].items():
                print(f"  {key}: {value}")
        
        if config['hardware']:
            hw = config['hardware']
            
            # CPU Info
            if 'cpu' in hw and hw['cpu']:
                print(f"\nCPU Information:")
                for key, value in hw['cpu'].items():
                    print(f"  {key}: {value}")
            
            # Network Info
            if 'network' in hw:
                net = hw['network']
                
                if 'pci_devices' in net:
                    print(f"\nPCI Network Devices:")
                    for dev in net['pci_devices']:
                        print(f"  • {dev}")
                
                if 'lshw' in net:
                    print(f"\nNetwork Hardware (lshw):")
                    lshw_data = net['lshw']
                    if isinstance(lshw_data, list):
                        for device in lshw_data:
                            if isinstance(device, dict):
                                print(f"  • {device.get('product', 'Unknown')}")
                                if 'logicalname' in device:
                                    print(f"    Interface: {device['logicalname']}")
                                if 'vendor' in device:
                                    print(f"    Vendor: {device['vendor']}")
                                if 'configuration' in device:
                                    config_dict = device['configuration']
                                    if 'speed' in config_dict:
                                        print(f"    Speed: {config_dict['speed']}")
                
                if 'driver_info' in net:
                    print(f"\nNIC Driver Information:")
                    print(net['driver_info'])
        else:
            print("\nNo hardware inventory data available for this host.")
        
        print("\n" + "=" * 80)


def main():
    parser = argparse.ArgumentParser(
        description='Extract and correlate lab configuration and hardware inventory',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Display summary
  %(prog)s --env env.json --testbed testbed.json --summary
  
  # Get specific environment value
  %(prog)s --env env.json --key KUBECONFIG
  
  # Search for keys
  %(prog)s --env env.json --search SRIOV
  
  # Get details for specific host
  %(prog)s --env env.json --testbed testbed.json --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com
  
  # List all hosts
  %(prog)s --env env.json --list-hosts
  
  # List all NICs with models
  %(prog)s --env env.json --testbed testbed.json --list-nics
  
  # Export to bash
  %(prog)s --env env.json --export-bash env_vars.sh
  
  # JSON output
  %(prog)s --env env.json --testbed testbed.json --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com --json
        """
    )
    
    parser.add_argument('--env', required=True,
                        help='Path to environment JSON file (env.json)')
    parser.add_argument('--testbed',
                        help='Path to testbed inventory JSON file (testbed.json)')
    parser.add_argument('--key',
                        help='Get value for specific environment key')
    parser.add_argument('--search',
                        help='Search for environment keys containing pattern')
    parser.add_argument('--host',
                        help='Display detailed information for specific host')
    parser.add_argument('--list-hosts', action='store_true',
                        help='List all hosts')
    parser.add_argument('--list-nics', action='store_true',
                        help='List all NICs with their models')
    parser.add_argument('--network', action='store_true',
                        help='Show network configuration')
    parser.add_argument('--summary', action='store_true',
                        help='Display comprehensive summary')
    parser.add_argument('--export-bash', metavar='FILE',
                        help='Export environment as bash variables to file')
    parser.add_argument('--json', action='store_true',
                        help='Output results as JSON')
    
    args = parser.parse_args()
    
    # Create extractor
    extractor = LabExtractor(args.env, args.testbed)
    
    # Handle operations
    if args.summary:
        extractor.display_summary()
    
    elif args.key:
        value = extractor.get_env_value(args.key)
        if args.json:
            print(json.dumps({args.key: value}, indent=2))
        else:
            print(value if value is not None else f"Key '{args.key}' not found")
    
    elif args.search:
        results = extractor.search_env(args.search)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            if results:
                for key, value in results.items():
                    print(f"{key}: {value}")
            else:
                print(f"No keys found matching '{args.search}'")
    
    elif args.host:
        if args.json:
            config = extractor.get_host_config(args.host)
            print(json.dumps(config, indent=2))
        else:
            extractor.display_host_details(args.host)
    
    elif args.list_hosts:
        hosts = extractor.all_hosts
        if args.json:
            print(json.dumps({"hosts": hosts}, indent=2))
        else:
            print(f"All Hosts ({len(hosts)}):")
            for host in hosts:
                config = extractor.get_host_config(host)
                roles = ', '.join(config['roles']) if config['roles'] else 'Unknown'
                print(f"  {host} ({roles})")
    
    elif args.list_nics:
        nics = extractor.list_nics_with_models()
        if args.json:
            print(json.dumps({"nics": nics}, indent=2))
        else:
            print("Network Interfaces:")
            for nic in nics:
                if nic.get("source") == "env_config":
                    print(f"  {nic['interface']} - Type: {nic['type']}, Model: {nic['model']}, Source: Environment Config")
                    if nic.get('mtu'):
                        print(f"    MTU: {nic['mtu']}")
                else:
                    print(f"  {nic['hostname']} - {nic['pci_device']}")
    
    elif args.network:
        network = extractor.get_network_config()
        if args.json:
            print(json.dumps(network, indent=2))
        else:
            for net_type, config in network.items():
                print(f"{net_type.upper()}:")
                for key, value in config.items():
                    if value:
                        print(f"  {key}: {value}")
    
    elif args.export_bash:
        extractor.export_bash(args.export_bash)
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()


