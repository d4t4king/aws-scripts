#!/usr/bin/env python3
"""
inventory_to_hosts.py

Read an Ansible inventory file (YAML or INI) and print lines in the format:

  ip_address|hostname

Usage:
  ./inventory_to_hosts.py /path/to/inventory.yml

Notes:
 - Prefers using `ansible-inventory -i <file> --list` to produce a normalized JSON
   representation if the `ansible-inventory` command is available.
 - Falls back to parsing YAML directly if `PyYAML` is installed; otherwise will
   attempt a best-effort parse and DNS resolution for missing IPs.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import socket
from pathlib import Path
from typing import Dict, Tuple, Optional


def run_ansible_inventory(inventory_path: str) -> Optional[Dict]:
    """Run `ansible-inventory -i <path> --list` and return parsed JSON or None."""
    try:
        proc = subprocess.run([
            'ansible-inventory',
            '-i',
            inventory_path,
            '--list'
        ], capture_output=True, text=True, check=True, timeout=30)
        return json.loads(proc.stdout)
    except FileNotFoundError:
        return None
    except subprocess.CalledProcessError:
        return None
    except Exception:
        return None


def try_import_yaml():
    try:
        import yaml  # type: ignore
        return yaml
    except Exception:
        return None


def parse_yaml_inventory(path: str) -> Optional[Dict]:
    yaml = try_import_yaml()
    if yaml is None:
        return None
    try:
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        return data
    except Exception:
        return None


def extract_hosts_from_ansible_inventory(inv: Dict) -> Dict[str, Dict]:
    """Given ansible-inventory --list JSON, return mapping host -> hostvars dict."""
    hosts = {}
    # hostvars under _meta is the canonical place
    hostvars = inv.get('_meta', {}).get('hostvars', {}) if isinstance(inv, dict) else {}
    if hostvars:
        for h, hv in hostvars.items():
            hosts[h] = hv or {}
        return hosts

    # Fallback: inventory groups may list hosts
    for key, val in (inv.items() if isinstance(inv, dict) else []):
        if key.startswith('_'):
            continue
        group = val or {}
        group_hosts = group.get('hosts') if isinstance(group, dict) else None
        if group_hosts:
            for h, hv in group_hosts.items() if isinstance(group_hosts, dict) else enumerate(group_hosts):
                if isinstance(group_hosts, dict):
                    hosts[h] = hv or {}
                else:
                    hosts[group_hosts] = hosts.get(group_hosts, {})

    return hosts


def extract_hosts_from_yaml_structure(data: Dict) -> Dict[str, Dict]:
    """Try to extract hosts mapping from a plain YAML inventory structure."""
    hosts = {}
    if not isinstance(data, dict):
        return hosts

    # top-level 'all' -> 'hosts'
    all_group = data.get('all') if 'all' in data else data
    if isinstance(all_group, dict):
        maybe_hosts = all_group.get('hosts')
        if isinstance(maybe_hosts, dict):
            for h, hv in maybe_hosts.items():
                hosts[h] = hv if isinstance(hv, dict) else {}
            return hosts

    # Otherwise, scan groups for 'hosts'
    for grp_name, grp in data.items():
        if not isinstance(grp, dict):
            continue
        maybe_hosts = grp.get('hosts')
        if isinstance(maybe_hosts, dict):
            for h, hv in maybe_hosts.items():
                if h not in hosts:
                    hosts[h] = hv if isinstance(hv, dict) else {}

    # Lastly, if the top-level is a map of hosts directly
    # e.g., { host1: { vars... }, host2: ... }
    for k, v in data.items():
        if isinstance(v, dict) and ('ansible_host' in v or 'ansible_ssh_host' in v):
            if k not in hosts:
                hosts[k] = v

    return hosts


def determine_ip_for_host(hostname: str, hostvars: Dict) -> Optional[str]:
    """Determine the best IP for a host given its variables"""
    # Priority: ansible_host, ansible_ssh_host, ansible_default_ipv4.address, inventory_ip, hostvar 'ip'
    candidates = []
    for key in ('ansible_host', 'ansible_ssh_host', 'ip', 'inventory_ip'):
        val = hostvars.get(key)
        if isinstance(val, str) and val:
            candidates.append(val)

    # ansible_default_ipv4 may be a mapping
    if isinstance(hostvars.get('ansible_default_ipv4'), dict):
        addr = hostvars['ansible_default_ipv4'].get('address')
        if addr:
            candidates.append(addr)

    # Try nested ansible_facts
    facts = hostvars.get('ansible_facts') or hostvars.get('ansible')
    if isinstance(facts, dict):
        default4 = facts.get('ansible_default_ipv4') or facts.get('default_ipv4')
        if isinstance(default4, dict):
            addr = default4.get('address')
            if addr:
                candidates.append(addr)

    # Return first candidate that looks like an IP or hostname resolvable
    for c in candidates:
        if c:
            # If it's already an IP-like string, accept it
            if is_ip_like(c):
                return c
            # else try to resolve
            try:
                ip = socket.gethostbyname(c)
                return ip
            except Exception:
                continue

    # Last resort: DNS-resolve the hostname itself
    try:
        return socket.gethostbyname(hostname)
    except Exception:
        return None


def is_ip_like(s: str) -> bool:
    parts = s.split('.')
    if len(parts) != 4:
        return False
    try:
        return all(0 <= int(p) <= 255 for p in parts)
    except Exception:
        return False


def build_ip_hostname_lines(hosts_mapping: Dict[str, Dict]) -> Dict[str, Optional[str]]:
    """Return dict hostname -> ip (or None if unknown)"""
    out = {}
    for host, vars in hosts_mapping.items():
        ip = determine_ip_for_host(host, vars or {})
        out[host] = ip
    return out


def main():
    parser = argparse.ArgumentParser(description='Produce lines "ip|hostname" from an Ansible inventory file')
    parser.add_argument('inventory', help='Path to Ansible inventory file (YAML, INI, or directory)')
    parser.add_argument('--skip-resolve', action='store_true', help='Do not DNS-resolve hostnames as fallback')
    args = parser.parse_args()

    inv_path = args.inventory
    if not Path(inv_path).exists():
        print(f"Inventory path not found: {inv_path}", file=sys.stderr)
        sys.exit(2)

    # Try ansible-inventory first
    inv_json = run_ansible_inventory(inv_path)
    hosts_mapping = {}
    if inv_json:
        hosts_mapping = extract_hosts_from_ansible_inventory(inv_json)
    else:
        # Try parsing YAML directly
        yaml_data = parse_yaml_inventory(inv_path)
        if yaml_data is not None:
            hosts_mapping = extract_hosts_from_yaml_structure(yaml_data)
        else:
            print("Could not parse inventory: neither 'ansible-inventory' available nor PyYAML installed.", file=sys.stderr)
            sys.exit(3)

    ipmap = build_ip_hostname_lines(hosts_mapping)

    for host, ip in ipmap.items():
        if ip is None and args.skip_resolve:
            # Print blank IP to indicate unknown
            print(f"|{host}")
        elif ip is None:
            print(f"# skipped (no IP) |{host}")
        else:
            print(f"{ip}|{host}")


if __name__ == '__main__':
    main()
