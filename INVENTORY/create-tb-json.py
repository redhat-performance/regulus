#!/usr/bin/env python3
"""
OCP  Node Hardware Collector
SSH into worker nodes to collect CPU and NIC information

Usage: python3 create-tb-json.py --kubeconfig $KUBECONFIG  --ssh-key ~/.ssh/id_rsa  --lshw /usr/sbin/lshw  --lab-config lab.config --json --output DATA/testbed.json

"""

import subprocess
import sys
import os
import argparse
import re
from pathlib import Path
from datetime import datetime


class NodeHardwareCollector:
    """Collect hardware info from OpenShift nodes via SSH"""
    
    def __init__(self, kubeconfig=None, ssh_key=None, output_file="hardware_info.txt", lshw_path=None, json_output=False, lab_config=None):
        self.kubeconfig = kubeconfig
        self.ssh_key = ssh_key
        self.output_file = output_file
        self.lshw_path = lshw_path or "lshw"
        self.json_output = json_output
        self.lab_config = lab_config
        self.collected_data = {}  # For JSON mode
        self.oc_cmd = ["oc"]
        if kubeconfig:
            self.oc_cmd.extend(["--kubeconfig", kubeconfig])
    
    def parse_lab_config(self):
        """Parse lab.config file to extract OCP_WORKER_*, BM_HOSTS, and TREX_HOSTS"""
        if not self.lab_config:
            return [], [], []
        
        worker_hosts = []
        bm_hosts = []
        trex_hosts = []
        
        try:
            with open(self.lab_config, 'r') as f:
                for line in f:
                    line = line.strip()
                    
                    # Skip comments and empty lines
                    if not line or line.startswith('#'):
                        continue
                    
                    # Match OCP_WORKER_* variables
                    worker_match = re.match(r'export\s+OCP_WORKER_\d+\s*=\s*"([^"]+)"', line)
                    if worker_match:
                        hostname = worker_match.group(1)
                        if hostname and hostname not in worker_hosts:
                            worker_hosts.append(hostname)
                        continue
                    
                    # Match BM_HOSTS variable (space-separated list)
                    bm_match = re.match(r'export\s+BM_HOSTS\s*=\s*"([^"]+)"', line)
                    if bm_match:
                        hosts_str = bm_match.group(1)
                        # Split by whitespace and add unique hosts
                        for host in hosts_str.split():
                            host = host.strip()
                            if host and host not in bm_hosts:
                                bm_hosts.append(host)
                        continue
                    
                    # Match TREX_HOSTS variable (space-separated list)
                    trex_match = re.match(r'export\s+TREX_HOSTS\s*=\s*"([^"]+)"', line)
                    if trex_match:
                        hosts_str = trex_match.group(1)
                        # Split by whitespace and add unique hosts
                        for host in hosts_str.split():
                            host = host.strip()
                            if host and host not in trex_hosts:
                                trex_hosts.append(host)
                        continue
            
            print(f"Parsed lab.config:")
            print(f"  OCP Workers: {worker_hosts}")
            print(f"  BM Hosts: {bm_hosts}")
            print(f"  TREX Hosts: {trex_hosts}")
            
            return worker_hosts, bm_hosts, trex_hosts
            
        except FileNotFoundError:
            print(f"ERROR: Lab config file not found: {self.lab_config}", file=sys.stderr)
            return [], [], []
        except Exception as e:
            print(f"ERROR parsing lab config: {e}", file=sys.stderr)
            return [], [], []
    
    def run_command(self, command, capture_output=True):
        """Execute a command and return result"""
        try:
            if capture_output:
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                return result.stdout.strip(), result.stderr, result.returncode
            else:
                result = subprocess.run(command, timeout=30)
                return "", "", result.returncode
        except Exception as e:
            print(f"Error running command: {e}", file=sys.stderr)
            return "", str(e), 1
    
    def get_control_plane_nodes(self):
        """Get list of control plane node names from the cluster"""
        nodes_cmd = self.oc_cmd + ["get", "nodes", "-l", "node-role.kubernetes.io/control-plane", "--no-headers"]
        stdout, stderr, returncode = self.run_command(nodes_cmd)
        
        if returncode != 0:
            print(f"Warning: Could not get control plane nodes: {stderr}", file=sys.stderr)
            return []
        
        nodes = []
        for line in stdout.split("\n"):
            if line.strip():
                # First column is node name
                node_name = line.split()[0]
                nodes.append(node_name)
        
        return nodes
    
    def get_node_list(self):
        """Get list of node names from the cluster"""
        nodes_cmd = self.oc_cmd + ["get", "node", "--no-headers"]
        stdout, stderr, returncode = self.run_command(nodes_cmd)
        
        if returncode != 0:
            print(f"Error getting nodes: {stderr}", file=sys.stderr)
            return []
        
        nodes = []
        for line in stdout.split("\n"):
            if line.strip():
                # First column is node name
                node_name = line.split()[0]
                nodes.append(node_name)
        
        return nodes
    
    def ssh_to_node(self, node_name, command, use_sudo=True, ssh_user="core"):
        """SSH into a node and execute a command"""
        ssh_cmd = [
            "ssh",
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=10",
            "-o", "LogLevel=ERROR"
        ]
        
        if self.ssh_key:
            ssh_cmd.extend(["-i", self.ssh_key])
        
        ssh_cmd.append(f"{ssh_user}@{node_name}")
        
        # Prepend sudo if needed
        if use_sudo and ssh_user != "root":
            command = f"sudo {command}"
        
        ssh_cmd.append(command)
        
        stdout, stderr, returncode = self.run_command(ssh_cmd)
        return stdout, returncode
    
    def scp_to_node(self, local_file, node_name, remote_path="~", ssh_user="core"):
        """Copy file to node via SCP"""
        scp_cmd = [
            "scp",
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=10",
            "-o", "LogLevel=ERROR"
        ]
        
        if self.ssh_key:
            scp_cmd.extend(["-i", self.ssh_key])
        
        scp_cmd.extend([local_file, f"{ssh_user}@{node_name}:{remote_path}"])
        
        stdout, stderr, returncode = self.run_command(scp_cmd)
        return returncode == 0
    
    def write_output(self, text, print_also=True):
        """Write text to output file and optionally print"""
        with open(self.output_file, "a") as f:
            f.write(text + "\n")
        
        if print_also:
            print(text)
    
    def collect_cpu_info(self, node_name, ssh_user="core"):
        """Collect CPU information using lscpu"""
        print(f"  Collecting CPU info from {node_name}...")
        output, returncode = self.ssh_to_node(node_name, "lscpu", use_sudo=False, ssh_user=ssh_user)
        
        if returncode == 0:
            # Filter for relevant lines
            filtered_lines = []
            keywords = ['Model name', 'Socket', 'Thread', 'NUMA', 'CPU(s)']
            
            for line in output.split("\n"):
                if any(keyword in line for keyword in keywords):
                    filtered_lines.append(line)
            
            result = "\n".join(filtered_lines)
            self.write_output(result)
        else:
            self.write_output("  ERROR: Failed to collect CPU info")
    
    def collect_network_pci(self, node_name, ssh_user="core"):
        """Collect network PCI devices using lspci"""
        print(f"  Collecting PCI network devices from {node_name}...")
        output, returncode = self.ssh_to_node(node_name, "lspci", use_sudo=False, ssh_user=ssh_user)
        
        if returncode == 0:
            # Filter for network/ethernet devices
            filtered_lines = []
            for line in output.split("\n"):
                if any(keyword in line.lower() for keyword in ['network', 'ethernet']):
                    filtered_lines.append(line)
            
            result = "\n".join(filtered_lines)
            self.write_output(result)
        else:
            self.write_output("  ERROR: Failed to collect PCI info")
    
    def collect_network_lshw(self, node_name, ssh_user="core"):
        """Collect network info using lshw (with JSON and human-readable output)"""
        print(f"  Collecting lshw network info from {node_name}...")
        
        use_sudo = (ssh_user != "root")
        lshw_copied = False
        lshw_remote_path = "lshw"
        
        # Check if lshw binary exists locally
        if Path(self.lshw_path).exists():
            print(f"    Copying lshw binary to {node_name}...")
            # Copy lshw to the node
            if self.scp_to_node(self.lshw_path, node_name, lshw_remote_path, ssh_user):
                lshw_copied = True
                # Make it executable
                self.ssh_to_node(node_name, f"chmod +x {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
                
                # Run lshw with JSON output
                output_json, returncode_json = self.ssh_to_node(node_name, f"./{lshw_remote_path} -C network -json 2>/dev/null", use_sudo=use_sudo, ssh_user=ssh_user)
                
                if returncode_json == 0 and output_json.strip():
                    # Write JSON output
                    self.write_output("--- Network Hardware (JSON) ---")
                    self.write_output(output_json)
                    
                    # Also get human-readable short format for text output
                    output_short, returncode_short = self.ssh_to_node(node_name, f"./{lshw_remote_path} -C network -short", use_sudo=use_sudo, ssh_user=ssh_user)
                    if returncode_short == 0 and output_short.strip():
                        self.write_output("\n--- Network Hardware (Human Readable) ---")
                        self.write_output(output_short)
                else:
                    self.write_output(f"  WARNING: lshw command failed (user: {ssh_user})")
                
                # Cleanup: remove lshw binary from node
                print(f"    Cleaning up lshw from {node_name}...")
                self.ssh_to_node(node_name, f"rm -f {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
            else:
                self.write_output("  WARNING: Failed to copy lshw binary to node")
        else:
            # Try using system lshw if available on node
            output, returncode = self.ssh_to_node(node_name, "which lshw", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0 and output.strip():
                # lshw exists on system - try JSON output
                output_json, returncode_json = self.ssh_to_node(node_name, "lshw -C network -json 2>/dev/null", use_sudo=use_sudo, ssh_user=ssh_user)
                if returncode_json == 0 and output_json.strip():
                    self.write_output("--- Network Hardware (JSON) ---")
                    self.write_output(output_json)
                    
                    # Also get short format
                    output_short, returncode_short = self.ssh_to_node(node_name, "lshw -C network -short 2>/dev/null", use_sudo=use_sudo, ssh_user=ssh_user)
                    if returncode_short == 0 and output_short.strip():
                        self.write_output("\n--- Network Hardware (Human Readable) ---")
                        self.write_output(output_short)
                else:
                    self.write_output("  WARNING: lshw exists but command failed")
            else:
                self.write_output(f"  INFO: lshw not available (local path: {self.lshw_path} not found, and not installed on node)")
                self.write_output(f"  TIP: Provide lshw binary path with --lshw option")
    
    def collect_ovs_ports(self, node_name, ssh_user="core"):
        """Collect OVS port information using nmcli"""
        print(f"  Collecting OVS port info from {node_name}...")
        use_sudo = (ssh_user != "root")
        output, returncode = self.ssh_to_node(node_name, "nmcli", use_sudo=use_sudo, ssh_user=ssh_user)
        
        if returncode == 0:
            # Filter for ovs-port-phys0 lines (mimics: egrep ovs-port-phys0)
            filtered_lines = []
            for line in output.split("\n"):
                if "ovs-port-phys0" in line:
                    filtered_lines.append(line)
            
            if filtered_lines:
                result = "\n".join(filtered_lines)
                self.write_output(result)
            else:
                self.write_output("  INFO: No OVS ports found")
        else:
            self.write_output("  WARNING: Failed to collect nmcli info")
    
    def collect_additional_network_info(self, node_name, ssh_user="core"):
        """Collect additional network interface information"""
        print(f"  Collecting additional network info from {node_name}...")
        
        use_sudo = (ssh_user != "root")
        
        # Get interface details
        output, returncode = self.ssh_to_node(node_name, "ip addr show", use_sudo=False, ssh_user=ssh_user)
        if returncode == 0:
            self.write_output("--- IP Addresses ---")
            self.write_output(output)
        
        # Get NIC driver and firmware info
        cmd = "for i in $(ls /sys/class/net/ | grep -v lo); do echo '=== '$i' ==='; ethtool -i $i 2>/dev/null; done"
        output, returncode = self.ssh_to_node(node_name, cmd, use_sudo=use_sudo, ssh_user=ssh_user)
        if returncode == 0 and output.strip():
            self.write_output("--- NIC Driver/Firmware Info ---")
            self.write_output(output)
    
    def collect_from_node(self, node_name, ssh_user="core", node_type="worker"):
        """Collect all hardware info from a single node"""
        if self.json_output:
            # JSON mode - collect structured data
            node_data = {
                "name": node_name,
                "type": node_type,
                "ssh_user": ssh_user,
                "cpu": {},
                "network": {},
                "collection_time": datetime.now().isoformat()
            }
            
            use_sudo = (ssh_user != "root")
            
            # CPU info
            output, returncode = self.ssh_to_node(node_name, "lscpu", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0:
                cpu_info = {}
                keywords = ['Model name', 'Socket', 'Thread', 'NUMA', 'CPU(s)']
                for line in output.split("\n"):
                    if any(keyword in line for keyword in keywords):
                        if ":" in line:
                            key, value = line.split(":", 1)
                            cpu_info[key.strip()] = value.strip()
                node_data["cpu"] = cpu_info
            
            # Network PCI
            output, returncode = self.ssh_to_node(node_name, "lspci", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0:
                pci_devices = []
                for line in output.split("\n"):
                    if any(keyword in line.lower() for keyword in ['network', 'ethernet']):
                        pci_devices.append(line.strip())
                node_data["network"]["pci_devices"] = pci_devices
            
            # lshw JSON
            lshw_remote_path = "lshw"
            if Path(self.lshw_path).exists():
                print(f"    Copying lshw to {node_name}...")
                if self.scp_to_node(self.lshw_path, node_name, lshw_remote_path, ssh_user):
                    self.ssh_to_node(node_name, f"chmod +x {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
                    output_json, returncode = self.ssh_to_node(node_name, f"./{lshw_remote_path} -C network -json 2>/dev/null", use_sudo=use_sudo, ssh_user=ssh_user)
                    if returncode == 0 and output_json.strip():
                        try:
                            import json as json_module
                            lshw_data = json_module.loads(output_json)
                            node_data["network"]["lshw"] = lshw_data
                        except json_module.JSONDecodeError:
                            node_data["network"]["lshw_raw"] = output_json
                    print(f"    Cleaning up lshw from {node_name}...")
                    self.ssh_to_node(node_name, f"rm -f {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
            
            # OVS ports
            output, returncode = self.ssh_to_node(node_name, "nmcli", use_sudo=use_sudo, ssh_user=ssh_user)
            if returncode == 0:
                ovs_ports = []
                for line in output.split("\n"):
                    if "ovs-port-phys0" in line:
                        ovs_ports.append(line.strip())
                if ovs_ports:
                    node_data["network"]["ovs_ports"] = ovs_ports
            
            # IP addresses (try JSON format first)
            output, returncode = self.ssh_to_node(node_name, "ip -json addr show 2>/dev/null", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0 and output.strip():
                try:
                    import json as json_module
                    node_data["network"]["interfaces"] = json_module.loads(output)
                except json_module.JSONDecodeError:
                    # Fallback to text
                    output, returncode = self.ssh_to_node(node_name, "ip addr show", use_sudo=False, ssh_user=ssh_user)
                    if returncode == 0:
                        node_data["network"]["interfaces_raw"] = output
            
            # Ethtool info
            cmd = "for i in $(ls /sys/class/net/ | grep -v lo); do echo '=== '$i' ==='; ethtool -i $i 2>/dev/null; done"
            output, returncode = self.ssh_to_node(node_name, cmd, use_sudo=use_sudo, ssh_user=ssh_user)
            if returncode == 0 and output.strip():
                node_data["network"]["driver_info"] = output
            
            self.collected_data[node_name] = node_data
            
        else:
            # Text mode - original behavior
            separator = "-" * 60
            self.write_output(f"\nName: {node_name} (Type: {node_type}, User: {ssh_user}):")
            self.write_output(separator)
            
            # Collect CPU info
            self.collect_cpu_info(node_name, ssh_user)
            
            # Collect network PCI devices
            self.collect_network_pci(node_name, ssh_user)
            
            # Collect lshw network info (both JSON and human-readable)
            self.collect_network_lshw(node_name, ssh_user)
            
            # Collect OVS ports
            self.collect_ovs_ports(node_name, ssh_user)
            
            # Collect additional network info
            self.collect_additional_network_info(node_name, ssh_user)
            
            self.write_output("")  # Empty line between nodes
    
    def collect_all(self):
        """Main collection function - mimics get_cpu_nic bash function"""
        print("get_cpu_nic: enter")
        
        if not self.json_output:
            # Initialize output file for text mode
            with open(self.output_file, "w") as f:
                f.write(f"OpenShift Node Hardware Collection\n")
                f.write(f"Collection Time: {datetime.now().isoformat()}\n")
                f.write("-" * 60 + "\n")
        
        # Get control plane nodes if kubeconfig is available
        control_plane_nodes = []
        if self.kubeconfig or self.lab_config:
            control_plane_nodes = self.get_control_plane_nodes()
            if control_plane_nodes:
                print(f"\nControl Plane Nodes ({len(control_plane_nodes)}):")
                for node in control_plane_nodes:
                    print(f"  - {node}")
        
        # Parse lab config if provided
        if self.lab_config:
            worker_hosts, bm_hosts, trex_hosts = self.parse_lab_config()
            
            if not worker_hosts and not bm_hosts and not trex_hosts:
                print("WARNING: No hosts found in lab.config", file=sys.stderr)
                return False
            
            # Collect from worker hosts (SSH as core user)
            if worker_hosts:
                print(f"\n{'='*60}")
                print(f"Collecting from OCP Workers ({len(worker_hosts)} hosts)")
                print(f"{'='*60}")
                for node_name in worker_hosts:
                    print(f"\n{node_name} (OCP Worker):")
                    try:
                        self.collect_from_node(node_name, ssh_user="core", node_type="ocp_worker")
                    except Exception as e:
                        error_msg = f"ERROR collecting from {node_name}: {e}"
                        print(error_msg, file=sys.stderr)
                        if not self.json_output:
                            self.write_output(error_msg)
                        else:
                            self.collected_data[node_name] = {"error": str(e), "name": node_name, "type": "ocp_worker"}
            
            # Get unique external servers (BM + TREX, deduplicated)
            external_servers = []
            external_server_set = set()
            
            # Add BM hosts to external servers
            for host in bm_hosts:
                if host not in external_server_set:
                    external_servers.append(host)
                    external_server_set.add(host)
            
            # Add TREX hosts to external servers (skip duplicates)
            for host in trex_hosts:
                if host not in external_server_set:
                    external_servers.append(host)
                    external_server_set.add(host)
            
            # Collect from unique external servers (SSH as root user)
            if external_servers:
                print(f"\n{'='*60}")
                print(f"Collecting from External Servers ({len(external_servers)} unique hosts)")
                print(f"{'='*60}")
                for node_name in external_servers:
                    # Determine which categories this server belongs to
                    categories = []
                    if node_name in bm_hosts:
                        categories.append("bm_host")
                    if node_name in trex_hosts:
                        categories.append("trex_host")
                    
                    print(f"\n{node_name} (External Server: {', '.join(categories)}):")
                    try:
                        self.collect_from_node(node_name, ssh_user="root", node_type="external_server")
                    except Exception as e:
                        error_msg = f"ERROR collecting from {node_name}: {e}"
                        print(error_msg, file=sys.stderr)
                        if not self.json_output:
                            self.write_output(error_msg)
                        else:
                            self.collected_data[node_name] = {"error": str(e), "name": node_name, "type": "external_server"}
            
            total_hosts = len(worker_hosts) + len(external_servers)
            
        else:
            # Original behavior: get all nodes from cluster
            nodes = self.get_node_list()
            
            if not nodes:
                print("ERROR: No nodes found in cluster", file=sys.stderr)
                return False
            
            print(f"Found {len(nodes)} nodes")
            
            # Collect from each node
            for node_name in nodes:
                print(f"\n{node_name}:")
                try:
                    self.collect_from_node(node_name, ssh_user="core", node_type="cluster_node")
                except Exception as e:
                    error_msg = f"ERROR collecting from {node_name}: {e}"
                    print(error_msg, file=sys.stderr)
                    if not self.json_output:
                        self.write_output(error_msg)
                    else:
                        self.collected_data[node_name] = {"error": str(e)}
            
            total_hosts = len(nodes)
        
        # Write JSON output if in JSON mode
        if self.json_output:
            import json as json_module
            output_data = {
                "collection_time": datetime.now().isoformat(),
            }
            
            if self.lab_config:
                # Add control plane nodes with count first
                if control_plane_nodes:
                    output_data["control_plane_count"] = len(control_plane_nodes)
                    output_data["control_plane_nodes"] = control_plane_nodes
                
                # OCP workers with count first
                output_data["ocp_worker_count"] = len(worker_hosts)
                output_data["ocp_workers"] = worker_hosts
                
                # BM hosts with count first
                output_data["bm_host_count"] = len(bm_hosts)
                output_data["bm_hosts"] = bm_hosts
                
                # TREX hosts with count first
                output_data["trex_host_count"] = len(trex_hosts)
                output_data["trex_hosts"] = trex_hosts
                
                # Extract OCP worker details
                ocp_workers_details = {}
                for hostname in worker_hosts:
                    if hostname in self.collected_data:
                        ocp_workers_details[hostname] = self.collected_data[hostname]
                
                output_data["ocp_workers_details_count"] = len(ocp_workers_details)
                output_data["ocp_workers_details"] = ocp_workers_details
                
                # Extract external server details (deduplicated)
                external_servers_details = {}
                for hostname in external_servers:
                    if hostname in self.collected_data:
                        external_servers_details[hostname] = self.collected_data[hostname]
                
                output_data["external_servers_count"] = len(external_servers)
                output_data["external_servers"] = external_servers_details
            else:
                # Add control plane nodes with count first
                if control_plane_nodes:
                    output_data["control_plane_count"] = len(control_plane_nodes)
                    output_data["control_plane_nodes"] = control_plane_nodes
                
                # Flat structure for cluster mode
                output_data["node_count"] = total_hosts
                output_data["nodes"] = self.collected_data
            
            os.makedirs(os.path.dirname(self.output_file), exist_ok=True)
            with open(self.output_file, "w") as f:
                json_module.dump(output_data, f, indent=2)
        
        print(f"\nCollection complete! Output saved to: {self.output_file}")
        return True


def main():
    parser = argparse.ArgumentParser(
        description="Collect CPU and NIC information from OpenShift worker nodes via SSH",
        epilog="""
Examples:
  # Use lab.config to specify hosts (recommended)
  %(prog)s --lab-config lab.config --lshw /usr/sbin/lshw --output hw.txt

  # JSON output with lab.config
  %(prog)s --lab-config lab.config --lshw /usr/sbin/lshw --json --output hw.json

  # Collect from all cluster nodes (original behavior)
  %(prog)s --kubeconfig ~/.kube/config --lshw /usr/sbin/lshw --output hw.txt

  # With SSH key
  %(prog)s --lab-config lab.config --ssh-key ~/.ssh/id_rsa --lshw /usr/sbin/lshw --json --output hw.json

Note: The lshw binary will be copied to each node, executed, and then removed automatically.
      When using --lab-config:
        - OCP_WORKER_* hosts use 'core' user with sudo
        - BM_HOSTS use 'root' user (no sudo needed)
        - TREX_HOSTS use 'root' user (no sudo needed)
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--kubeconfig",
        help="Path to kubeconfig file (used only when --lab-config not specified)"
    )
    parser.add_argument(
        "--lab-config",
        help="Path to lab.config file containing OCP_WORKER_*, BM_HOSTS, and TREX_HOSTS variables"
    )
    parser.add_argument(
        "--ssh-key",
        help="Path to SSH private key for node access (if not using ssh-agent)"
    )
    parser.add_argument(
        "--output",
        default="hardware_info.txt",
        help="Output file path (default: hardware_info.txt)"
    )
    parser.add_argument(
        "--lshw",
        help="Path to lshw binary on local machine (will be copied to nodes). If not provided, will try to use lshw installed on nodes."
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output in JSON format instead of text (includes parsed lshw JSON data)"
    )
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.lab_config and not args.kubeconfig:
        print("ERROR: Either --lab-config or --kubeconfig must be specified", file=sys.stderr)
        sys.exit(1)
    
    # Create collector
    collector = NodeHardwareCollector(
        kubeconfig=args.kubeconfig,
        ssh_key=args.ssh_key,
        output_file=args.output,
        lshw_path=args.lshw,
        json_output=args.json,
        lab_config=args.lab_config
    )
    
    # Run collection
    success = collector.collect_all()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

