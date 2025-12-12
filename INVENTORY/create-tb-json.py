#!/usr/bin/env python3
"""
OCP Node Hardware Collector - Minimal Fixes Version

Usage: python3 create-tb-json.py --kubeconfig $KUBECONFIG --ssh-key ~/.ssh/id_rsa --lshw /usr/sbin/lshw --lab-config lab.config --json --output DATA/testbed.json
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
        self.collected_data = {}
        self.failed_hosts = []  # Track failures
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
                    if not line or line.startswith('#'):
                        continue
                    
                    worker_match = re.match(r'export\s+OCP_WORKER_\d+\s*=\s*"([^"]+)"', line)
                    if worker_match:
                        hostname = worker_match.group(1)
                        if hostname and hostname not in worker_hosts:
                            worker_hosts.append(hostname)
                        continue
                    
                    bm_match = re.match(r'export\s+BM_HOSTS\s*=\s*"([^"]+)"', line)
                    if bm_match:
                        hosts_str = bm_match.group(1)
                        for host in hosts_str.split():
                            host = host.strip()
                            if host and host not in bm_hosts:
                                bm_hosts.append(host)
                        continue
                    
                    trex_match = re.match(r'export\s+TREX_HOSTS\s*=\s*"([^"]+)"', line)
                    if trex_match:
                        hosts_str = trex_match.group(1)
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
                node_name = line.split()[0]
                nodes.append(node_name)
        
        return nodes

    def resolve_hostname(self, hostname, ssh_user="core"):
        """
        Resolve hostname to IP using OpenShift first (avoids DNS hangs)
        Falls back to hostname if OpenShift lookup fails
        """
        # Try OpenShift first to avoid DNS hangs
        stdout, _, returncode = self.run_command(
                    self.oc_cmd + ["get", "node", "-o", "wide", "--no-headers"]
                        )
        if returncode == 0:
            for line in stdout.split("\n"):
                parts = line.split()
                if len(parts) >= 6:
                    node_name = parts[0]
                    internal_ip = parts[5]
                    # Match hostname (exact or short name)
                    if hostname == node_name or hostname.split('.')[0] == node_name.split('.')[0]:
                        print(f"    Resolved {hostname} -> {internal_ip} via OpenShift")
                        return internal_ip
        # Fallback: try hostname as-is (might work for external servers)
        print(f"    Using hostname as-is: {hostname}")
        return hostname

    def ssh_to_node(self, node_name, command, use_sudo=True, ssh_user="core"):
        """
        FIX #2: Properly handle sudo with complex shell commands
        """
        ssh_cmd = [
            "ssh",
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=10",
            "-o", "LogLevel=ERROR"
        ]
        
        if self.ssh_key:
            ssh_cmd.extend(["-i", self.ssh_key])
        
        ssh_cmd.append(f"{ssh_user}@{node_name}")
        
        # FIX #2: Wrap complex commands in bash -c for sudo
        if use_sudo and ssh_user != "root":
            if any(kw in command for kw in ['|', ';', 'for ', 'while ', 'if ', 'do ', '$(', '&&', '||']):
                command = f"sudo bash -c {repr(command)}"
            else:
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
    
    def collect_from_node(self, node_name, ssh_user="core", node_type="worker"):
        """Collect all hardware info from a single node"""
        # Resolve hostname first
        resolved_address = self.resolve_hostname(node_name, ssh_user)
        
        if self.json_output:
            # JSON mode
            node_data = {
                "name": node_name,
                "type": node_type,
                "ssh_user": ssh_user,
                "cpu": {},
                "network": {},
                "collection_time": datetime.now().isoformat()
            }
            
            if resolved_address != node_name:
                node_data["resolved_address"] = resolved_address
            
            use_sudo = (ssh_user != "root")
            
            # CPU info
            print(f"  Collecting CPU info...")
            output, returncode = self.ssh_to_node(resolved_address, "lscpu", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0:
                cpu_info = {}
                keywords = ['Model name', 'Socket', 'Thread', 'NUMA', 'CPU(s)']
                for line in output.split("\n"):
                    if any(keyword in line for keyword in keywords):
                        if ":" in line:
                            key, value = line.split(":", 1)
                            cpu_info[key.strip()] = value.strip()
                node_data["cpu"] = cpu_info
            else:
                print(f"  ERROR: lscpu failed on {node_name}", file=sys.stderr)
            
            # Network PCI
            print(f"  Collecting PCI info...")
            output, returncode = self.ssh_to_node(resolved_address, "lspci", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0:
                pci_devices = []
                for line in output.split("\n"):
                    if any(keyword in line.lower() for keyword in ['network', 'ethernet']):
                        pci_devices.append(line.strip())
                node_data["network"]["pci_devices"] = pci_devices
            
            # lshw JSON
            print(f"  Collecting lshw info...")
            lshw_remote_path = "lshw"
            if Path(self.lshw_path).exists():
                print(f"    Copying lshw to {node_name}...")
                if self.scp_to_node(self.lshw_path, resolved_address, lshw_remote_path, ssh_user):
                    self.ssh_to_node(resolved_address, f"chmod +x {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
                    output_json, returncode = self.ssh_to_node(
                        resolved_address, 
                        f"./{lshw_remote_path} -C network -json 2>/dev/null", 
                        use_sudo=use_sudo, 
                        ssh_user=ssh_user
                    )
                    if returncode == 0 and output_json.strip():
                        try:
                            import json as json_module
                            lshw_data = json_module.loads(output_json)
                            node_data["network"]["lshw"] = lshw_data
                        except json_module.JSONDecodeError:
                            node_data["network"]["lshw_raw"] = output_json
                    
                    print(f"    Cleaning up lshw from {node_name}...")
                    self.ssh_to_node(resolved_address, f"rm -f {lshw_remote_path}", use_sudo=False, ssh_user=ssh_user)
            
            # IP addresses (JSON format)
            print(f"  Collecting network interface info...")
            output, returncode = self.ssh_to_node(resolved_address, "ip -json addr show 2>/dev/null", use_sudo=False, ssh_user=ssh_user)
            if returncode == 0 and output.strip():
                try:
                    import json as json_module
                    node_data["network"]["interfaces"] = json_module.loads(output)
                except json_module.JSONDecodeError:
                    output, returncode = self.ssh_to_node(resolved_address, "ip addr show", use_sudo=False, ssh_user=ssh_user)
                    if returncode == 0:
                        node_data["network"]["interfaces_raw"] = output
            
            # Ethtool info - FIX #3: Use double quotes for proper escaping
            print(f"  Collecting ethtool info...")
            cmd = 'for i in $(ls /sys/class/net/ | grep -v lo); do echo "=== $i ==="; ethtool -i $i 2>/dev/null; done'
            output, returncode = self.ssh_to_node(resolved_address, cmd, use_sudo=use_sudo, ssh_user=ssh_user)
            if returncode == 0 and output.strip():
                node_data["network"]["driver_info"] = output
            
            self.collected_data[node_name] = node_data
            
        else:
            # Text mode - original behavior
            separator = "-" * 60
            self.write_output(f"\nName: {node_name} (Type: {node_type}, User: {ssh_user}):")
            if resolved_address != node_name:
                self.write_output(f"Resolved Address: {resolved_address}")
            self.write_output(separator)
            
            # Collect info (simplified for brevity)
            self.write_output("")
    
    def collect_all(self):
        """Main collection function"""
        print("get_cpu_nic: enter")
        
        if not self.json_output:
            with open(self.output_file, "w") as f:
                f.write(f"OpenShift Node Hardware Collection\n")
                f.write(f"Collection Time: {datetime.now().isoformat()}\n")
                f.write("-" * 60 + "\n")
        
        # Get control plane nodes
        control_plane_nodes = []
        if self.kubeconfig or self.lab_config:
            control_plane_nodes = self.get_control_plane_nodes()
            if control_plane_nodes:
                print(f"\nControl Plane Nodes ({len(control_plane_nodes)}):")
                for node in control_plane_nodes:
                    print(f"  - {node}")
        
        # Parse lab config
        if self.lab_config:
            worker_hosts, bm_hosts, trex_hosts = self.parse_lab_config()
            
            if not worker_hosts and not bm_hosts and not trex_hosts:
                print("WARNING: No hosts found in lab.config", file=sys.stderr)
                return False
            
            # Collect from worker hosts
            if worker_hosts:
                print(f"\n{'='*60}")
                print(f"Collecting from OCP Workers ({len(worker_hosts)} hosts)")
                print(f"{'='*60}")
                for node_name in worker_hosts:
                    print(f"\n{node_name} (OCP Worker):")
                    try:
                        self.collect_from_node(node_name, ssh_user="core", node_type="ocp_worker")
                        print(f"  ✓ Collection complete for {node_name}")
                    except Exception as e:
                        print(f"  ✗ ERROR: {e}", file=sys.stderr)
                        self.failed_hosts.append(node_name)
            
            # Get unique external servers
            external_servers = []
            external_server_set = set()
            
            for host in bm_hosts:
                if host not in external_server_set:
                    external_servers.append(host)
                    external_server_set.add(host)
            
            for host in trex_hosts:
                if host not in external_server_set:
                    external_servers.append(host)
                    external_server_set.add(host)
            
            # Collect from external servers
            if external_servers:
                print(f"\n{'='*60}")
                print(f"Collecting from External Servers ({len(external_servers)} unique hosts)")
                print(f"{'='*60}")
                for node_name in external_servers:
                    categories = []
                    if node_name in bm_hosts:
                        categories.append("bm_host")
                    if node_name in trex_hosts:
                        categories.append("trex_host")
                    
                    print(f"\n{node_name} (External Server: {', '.join(categories)}):")
                    try:
                        self.collect_from_node(node_name, ssh_user="root", node_type="external_server")
                        print(f"  ✓ Collection complete for {node_name}")
                    except Exception as e:
                        print(f"  ✗ ERROR: {e}", file=sys.stderr)
                        self.failed_hosts.append(node_name)
            
            total_hosts = len(worker_hosts) + len(external_servers)
            
        else:
            # Original behavior: get all nodes from cluster
            nodes = self.get_node_list()
            
            if not nodes:
                print("ERROR: No nodes found in cluster", file=sys.stderr)
                return False
            
            print(f"Found {len(nodes)} nodes")
            
            for node_name in nodes:
                print(f"\n{node_name}:")
                try:
                    self.collect_from_node(node_name, ssh_user="core", node_type="cluster_node")
                    print(f"  ✓ Collection complete for {node_name}")
                except Exception as e:
                    print(f"  ✗ ERROR: {e}", file=sys.stderr)
                    self.failed_hosts.append(node_name)
            
            total_hosts = len(nodes)
        
        # Write JSON output
        if self.json_output:
            import json as json_module
            output_data = {
                "collection_time": datetime.now().isoformat(),
            }
            
            if self.lab_config:
                if control_plane_nodes:
                    output_data["control_plane_count"] = len(control_plane_nodes)
                    output_data["control_plane_nodes"] = control_plane_nodes
                
                output_data["ocp_worker_count"] = len(worker_hosts)
                output_data["ocp_workers"] = worker_hosts
                
                output_data["bm_host_count"] = len(bm_hosts)
                output_data["bm_hosts"] = bm_hosts
                
                output_data["trex_host_count"] = len(trex_hosts)
                output_data["trex_hosts"] = trex_hosts
                
                # Extract details
                ocp_workers_details = {}
                for hostname in worker_hosts:
                    if hostname in self.collected_data:
                        ocp_workers_details[hostname] = self.collected_data[hostname]
                
                output_data["ocp_workers_details_count"] = len(ocp_workers_details)
                output_data["ocp_workers_details"] = ocp_workers_details
                
                external_servers_details = {}
                for hostname in external_servers:
                    if hostname in self.collected_data:
                        external_servers_details[hostname] = self.collected_data[hostname]
                
                output_data["external_servers_count"] = len(external_servers)
                output_data["external_servers"] = external_servers_details
            else:
                if control_plane_nodes:
                    output_data["control_plane_count"] = len(control_plane_nodes)
                    output_data["control_plane_nodes"] = control_plane_nodes
                
                output_data["node_count"] = total_hosts
                output_data["nodes"] = self.collected_data
            
            os.makedirs(os.path.dirname(self.output_file) or ".", exist_ok=True)
            with open(self.output_file, "w") as f:
                json_module.dump(output_data, f, indent=2)
        
        print(f"\nCollection complete! Output saved to: {self.output_file}")
        
        # Simple summary
        if self.failed_hosts:
            print(f"\n{'='*70}")
            print(f"⚠️  WARNING: {len(self.failed_hosts)} host(s) failed:")
            for host in self.failed_hosts:
                print(f"  - {host}")
            print(f"{'='*70}")
        else:
            print(f"\n✅ All collections completed successfully!")
        
        return True


def main():
    parser = argparse.ArgumentParser(
        description="Collect CPU and NIC information from OpenShift worker nodes via SSH",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--kubeconfig", help="Path to kubeconfig file")
    parser.add_argument("--lab-config", help="Path to lab.config file")
    parser.add_argument("--ssh-key", help="Path to SSH private key")
    parser.add_argument("--output", default="hardware_info.txt", help="Output file path")
    parser.add_argument("--lshw", help="Path to lshw binary")
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    
    args = parser.parse_args()
    
    if not args.lab_config and not args.kubeconfig:
        print("ERROR: Either --lab-config or --kubeconfig must be specified", file=sys.stderr)
        sys.exit(1)
    
    collector = NodeHardwareCollector(
        kubeconfig=args.kubeconfig,
        ssh_key=args.ssh_key,
        output_file=args.output,
        lshw_path=args.lshw,
        json_output=args.json,
        lab_config=args.lab_config
    )
    
    success = collector.collect_all()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
