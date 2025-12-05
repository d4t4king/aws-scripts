#!/usr/bin/env python3
"""
install-cpan-modules.py

Script to find and parse a cpanfile, then install Perl modules using the
appropriate system package manager for the current platform.

Features:
- Search for cpanfile in specified directory or current directory
- Parse cpanfile to extract module names (lines prefixed with 'require')
- Cross-platform package manager detection (apt, yum, pacman, brew, etc.)
- User confirmation before installation
- Optional logging to file
- Robust error handling
"""

import os
import sys
import re
import platform
import subprocess
import argparse
import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import List, Tuple, Optional, Dict


def check_root_privileges() -> None:
    """
    Check if script is running as root.
    Exit if not running with sufficient privileges.
    """
    if os.geteuid() != 0:
        print("\033[91mERROR: This script must be run as root or with sudo\033[0m")
        print("Usage: sudo ./install-cpan-modules.py [options]")
        sys.exit(1)


class CpanModuleInstaller:
    """Handle cpanfile parsing and Perl module installation."""
    
    # Mapping of distribution IDs to package managers
    PACKAGE_MANAGERS = {
        'debian': ('apt', 'apt-get install'),
        'ubuntu': ('apt', 'apt-get install'),
        'raspbian': ('apt', 'apt-get install'),
        'rhel': ('yum', 'yum install'),
        'centos': ('yum', 'yum install'),
        'fedora': ('dnf', 'dnf install'),
        'arch': ('pacman', 'pacman -S'),
        'manjaro': ('pacman', 'pacman -S'),
        'opensuse': ('zypper', 'zypper install'),
        'alpine': ('apk', 'apk add'),
    }
    
    def __init__(self, log_file: Optional[str] = None):
        """
        Initialize the installer.
        
        Args:
            log_file: Optional path to log file for output
        """
        self.log_file = log_file
        self.log_buffer = []
        self.modules = []
        self.cpanfile_path = None
        self.package_manager = None
        self.package_manager_cmd = None
    
    def log(self, message: str, level: str = "INFO") -> None:
        """
        Log a message to console and optionally to file.
        
        Args:
            message: Message to log
            level: Log level (INFO, WARNING, ERROR, SUCCESS)
        """
        timestamp = ""
        if self.log_file:
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_entry = f"[{timestamp}] [{level}] {message}"
            self.log_buffer.append(log_entry)
        
        # Color coding for console output
        colors = {
            "INFO": "\033[94m",      # Blue
            "WARNING": "\033[93m",   # Yellow
            "ERROR": "\033[91m",     # Red
            "SUCCESS": "\033[92m",   # Green
        }
        reset = "\033[0m"
        color = colors.get(level, "")
        
        print(f"{color}{message}{reset}")
    
    def write_log(self) -> None:
        """Write buffered log entries to log file."""
        if self.log_file and self.log_buffer:
            try:
                with open(self.log_file, 'a') as f:
                    for entry in self.log_buffer:
                        f.write(entry + '\n')
                self.log(f"Log written to {self.log_file}", "SUCCESS")
            except IOError as e:
                self.log(f"Failed to write log file: {e}", "ERROR")
    
    def detect_package_manager(self) -> Tuple[Optional[str], Optional[str]]:
        """
        Detect the package manager for the current system.
        
        Returns:
            Tuple of (package_manager_name, install_command) or (None, None)
        """
        try:
            # Try to read /etc/os-release for distribution detection
            if os.path.exists('/etc/os-release'):
                with open('/etc/os-release', 'r') as f:
                    content = f.read().lower()
                    for distro_id, (pm_name, pm_cmd) in self.PACKAGE_MANAGERS.items():
                        if f'id={distro_id}' in content or f'id_like={distro_id}' in content:
                            self.log(f"Detected package manager: {pm_name}", "INFO")
                            return pm_name, pm_cmd
            
            # Fallback: check for macOS
            if sys.platform == 'darwin':
                self.log("Detected macOS - using brew", "INFO")
                return 'brew', 'brew install'
            
            # Try to detect by checking for package manager commands
            for manager_cmd in ['apt', 'apt-get', 'yum', 'dnf', 'pacman', 'zypper', 'apk']:
                result = subprocess.run(
                    ['which', manager_cmd],
                    capture_output=True,
                    timeout=5
                )
                if result.returncode == 0:
                    self.log(f"Detected package manager: {manager_cmd}", "INFO")
                    if manager_cmd in ['apt', 'apt-get']:
                        return 'apt', 'apt-get install'
                    elif manager_cmd == 'yum':
                        return 'yum', 'yum install'
                    elif manager_cmd == 'dnf':
                        return 'dnf', 'dnf install'
                    elif manager_cmd == 'pacman':
                        return 'pacman', 'pacman -S'
                    elif manager_cmd == 'zypper':
                        return 'zypper', 'zypper install'
                    elif manager_cmd == 'apk':
                        return 'apk', 'apk add'
            
            self.log("Could not detect package manager", "ERROR")
            return None, None
        
        except Exception as e:
            self.log(f"Error detecting package manager: {e}", "ERROR")
            return None, None
    
    def find_cpanfile(self, specified_path: Optional[str] = None) -> bool:
        """
        Find cpanfile in specified or current directory.
        
        Args:
            specified_path: Optional path to check first
            
        Returns:
            True if cpanfile found, False otherwise
        """
        search_paths = []
        
        if specified_path:
            specified_path = Path(specified_path)
            
            # Validate the specified path
            if not specified_path.exists():
                self.log(f"Specified path does not exist: {specified_path}", "ERROR")
                return False
            
            # If it's a directory, look for cpanfile in it
            if specified_path.is_dir():
                search_paths.append(specified_path / 'cpanfile')
                self.log(f"Checking specified directory: {specified_path}", "INFO")
            # If it's a file, check if it's named cpanfile
            elif specified_path.is_file():
                if specified_path.name == 'cpanfile':
                    search_paths.append(specified_path)
                    self.log(f"Using specified cpanfile: {specified_path}", "INFO")
                else:
                    self.log(f"Specified file is not named 'cpanfile': {specified_path}", "ERROR")
                    return False
        
        # Always check current directory as fallback
        current_cpanfile = Path.cwd() / 'cpanfile'
        if current_cpanfile not in search_paths:
            search_paths.append(current_cpanfile)
        
        # Search for cpanfile
        for cpanfile_path in search_paths:
            if cpanfile_path.exists() and cpanfile_path.is_file():
                self.cpanfile_path = cpanfile_path
                self.log(f"Found cpanfile: {cpanfile_path}", "SUCCESS")
                return True
        
        self.log(f"cpanfile not found in specified or current directory", "ERROR")
        return False
    
    def parse_cpanfile(self) -> bool:
        """
        Parse cpanfile to extract module names.
        
        Returns:
            True if parsing successful, False otherwise
        """
        if not self.cpanfile_path:
            self.log("No cpanfile path set", "ERROR")
            return False
        
        try:
            with open(self.cpanfile_path, 'r') as f:
                content = f.read()
            
            # Pattern to match 'require' or 'requires' statements
            # Matches: require 'Module::Name', version; or requires 'Module::Name';
            # Also matches: require Module::Name; or requires Module::Name;
            pattern = r"^\s*requires?\s+['\"]?([A-Za-z0-9:_-]+)['\"]?"
            
            self.modules = []
            for line in content.split('\n'):
                match = re.match(pattern, line.strip())
                if match:
                    module_name = match.group(1)
                    self.modules.append(module_name)
                    self.log(f"Found module: {module_name}", "INFO")
            
            if not self.modules:
                self.log("No modules found in cpanfile", "WARNING")
                return False
            
            self.log(f"Found {len(self.modules)} modules", "SUCCESS")
            return True
        
        except IOError as e:
            self.log(f"Error reading cpanfile: {e}", "ERROR")
            return False
        except Exception as e:
            self.log(f"Error parsing cpanfile: {e}", "ERROR")
            return False
    
    def convert_module_to_package(self, module_name: str) -> str:
        """
        Convert Perl module name to system package name.
        
        Args:
            module_name: Perl module name (e.g., 'JSON::XS')
            
        Returns:
            System package name (e.g., 'libjson-xs-perl')
        """
        # Convert module name to package name format
        # JSON::XS -> libjson-xs-perl
        package_name = module_name.lower().replace('::', '-')
        return f"lib{package_name}-perl"
    
    def is_package_installed(self, package_name: str) -> bool:
        """
        Check if a package is already installed.
        
        Args:
            package_name: System package name to check
            
        Returns:
            True if package is installed, False otherwise
        """
        try:
            # Use dpkg for Debian-based systems
            if self.package_manager in ['apt', 'apt-get']:
                result = subprocess.run(
                    ['dpkg', '-l', package_name],
                    capture_output=True,
                    timeout=5
                )
                return result.returncode == 0
            
            # Use rpm for RHEL-based systems
            elif self.package_manager in ['yum', 'dnf']:
                result = subprocess.run(
                    ['rpm', '-q', package_name],
                    capture_output=True,
                    timeout=5
                )
                return result.returncode == 0
            
            # Use pacman for Arch-based systems
            elif self.package_manager == 'pacman':
                result = subprocess.run(
                    ['pacman', '-Q', package_name],
                    capture_output=True,
                    timeout=5
                )
                return result.returncode == 0
            
            # Use zypper for openSUSE
            elif self.package_manager == 'zypper':
                result = subprocess.run(
                    ['zypper', 'se', '--installed-only', package_name],
                    capture_output=True,
                    timeout=5
                )
                return result.returncode == 0
            
            # Use apk for Alpine
            elif self.package_manager == 'apk':
                result = subprocess.run(
                    ['apk', 'info', package_name],
                    capture_output=True,
                    timeout=5
                )
                return result.returncode == 0
            
            # Fallback - assume not installed if can't determine
            return False
        
        except Exception as e:
            self.log(f"Error checking if {package_name} is installed: {e}", "WARNING")
            return False
    
    def search_cpan(self, module_name: str) -> Optional[Dict]:
        """
        Search CPAN for a module using the MetaCPAN API.
        
        Args:
            module_name: Perl module name (e.g., 'JSON::XS')
            
        Returns:
            Dictionary with module information if found, None otherwise
        """
        try:
            self.log(f"Searching CPAN for module: {module_name}...", "INFO")
            
            # Use MetaCPAN API to search for the module
            url = f"https://fastapi.metacpan.org/v1/module/{module_name}"
            
            # Set a timeout and user agent
            headers = {'User-Agent': 'install-cpan-modules/1.0'}
            req = urllib.request.Request(url, headers=headers)
            
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    
                    # Extract relevant information
                    module_info = {
                        'name': data.get('name'),
                        'version': data.get('version'),
                        'author': data.get('author'),
                        'abstract': data.get('abstract'),
                        'distribution': data.get('distribution'),
                    }
                    
                    self.log(f"Found on CPAN: {module_name} v{module_info.get('version', 'unknown')}", "SUCCESS")
                    return module_info
        
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.log(f"Module not found on CPAN: {module_name}", "WARNING")
            else:
                self.log(f"HTTP error searching CPAN: {e.code}", "WARNING")
        except urllib.error.URLError as e:
            self.log(f"Network error searching CPAN: {e.reason}", "WARNING")
        except json.JSONDecodeError:
            self.log(f"Error parsing CPAN response for {module_name}", "WARNING")
        except Exception as e:
            self.log(f"Unexpected error searching CPAN for {module_name}: {e}", "WARNING")
        
        return None
    
    def get_user_confirmation(self) -> bool:
        """
        Get user confirmation before installation.
        
        Returns:
            True if user confirms, False otherwise
        """
        print("\n" + "="*60)
        print("Perl Modules to Install:")
        print("="*60)
        for i, module in enumerate(self.modules, 1):
            package_name = self.convert_module_to_package(module)
            print(f"{i}. {module:30} -> {package_name}")
        
        print("="*60)
        print(f"Total modules: {len(self.modules)}")
        print(f"Package manager: {self.package_manager}")
        print("="*60)
        
        while True:
            response = input("\nProceed with installation? (yes/no): ").strip().lower()
            if response in ['yes', 'y']:
                return True
            elif response in ['no', 'n']:
                self.log("Installation cancelled by user", "WARNING")
                return False
            else:
                print("Please enter 'yes' or 'no'")
    
    def install_modules(self, dry_run: bool = False) -> bool:
        """
        Install Perl modules using the detected package manager.
        
        Args:
            dry_run: If True, show what would be installed without installing
            
        Returns:
            True if all installations successful, False otherwise
        """
        if not self.package_manager or not self.package_manager_cmd:
            self.log("Package manager not detected or configured", "ERROR")
            return False
        
        if not self.modules:
            self.log("No modules to install", "WARNING")
            return False
        
        failed_modules = []
        successful_modules = []
        skipped_modules = []
        not_found_modules = []
        
        for module in self.modules:
            package_name = self.convert_module_to_package(module)
            
            # Check if package is already installed
            if self.is_package_installed(package_name):
                self.log(f"Already installed: {module} ({package_name})", "SUCCESS")
                skipped_modules.append(module)
                continue
            
            if dry_run:
                self.log(f"[DRY RUN] Would install: {package_name}", "INFO")
                continue
            
            try:
                self.log(f"Installing {module} ({package_name})...", "INFO")
                cmd = f"{self.package_manager_cmd} {package_name}"
                
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                if result.returncode == 0:
                    self.log(f"Successfully installed: {module}", "SUCCESS")
                    successful_modules.append(module)
                else:
                    # Check if this is a "package not found" error
                    stderr_lower = result.stderr.lower()
                    stdout_lower = result.stdout.lower()
                    
                    # Common "not found" messages across different package managers
                    not_found_indicators = [
                        'not found',
                        'no package',
                        'package not available',
                        'unable to locate package',
                        'no matching package',
                        'could not find a match',
                    ]
                    
                    is_not_found = any(
                        indicator in stderr_lower or indicator in stdout_lower
                        for indicator in not_found_indicators
                    )
                    
                    if is_not_found:
                        self.log(
                            f"Package not found in system repository: {package_name}",
                            "WARNING"
                        )
                        # Search CPAN for this module
                        cpan_result = self.search_cpan(module)
                        if cpan_result:
                            self.log(
                                f"Module exists on CPAN (v{cpan_result.get('version', 'unknown')}). "
                                f"Try installing with: cpan install {module}",
                                "INFO"
                            )
                        not_found_modules.append(module)
                    else:
                        self.log(
                            f"Failed to install {module}. Error: {result.stderr}",
                            "ERROR"
                        )
                        failed_modules.append(module)
            
            except subprocess.TimeoutExpired:
                self.log(f"Installation timeout for: {module}", "ERROR")
                failed_modules.append(module)
            except Exception as e:
                self.log(f"Error installing {module}: {e}", "ERROR")
                failed_modules.append(module)
        
        # Summary
        print("\n" + "="*60)
        print("Installation Summary")
        print("="*60)
        print(f"Successful: {len(successful_modules)}/{len(self.modules)}")
        print(f"Already installed: {len(skipped_modules)}/{len(self.modules)}")
        if not_found_modules:
            print(f"Not found in repository: {len(not_found_modules)}/{len(self.modules)}")
        if failed_modules:
            print(f"Failed: {len(failed_modules)}/{len(self.modules)}")
        
        # Print details
        if not_found_modules:
            print("\nPackages not found in system repository (but checked on CPAN):")
            for module in not_found_modules:
                print(f"  - {module}")
        
        if failed_modules:
            print("\nFailed modules (other errors):")
            for module in failed_modules:
                print(f"  - {module}")
        
        print("="*60 + "\n")
        
        self.log(
            f"Installation complete: {len(successful_modules)} successful, "
            f"{len(skipped_modules)} skipped, {len(not_found_modules)} not found, "
            f"{len(failed_modules)} failed",
            "INFO"
        )
        
        return len(failed_modules) == 0
    
    def run(self, specified_path: Optional[str] = None, dry_run: bool = False) -> bool:
        """
        Main execution method.
        
        Args:
            specified_path: Optional path to cpanfile or directory
            dry_run: If True, show what would be installed without installing
            
        Returns:
            True if successful, False otherwise
        """
        # Step 1: Find cpanfile
        if not self.find_cpanfile(specified_path):
            self.write_log()
            return False
        
        # Step 2: Detect package manager
        self.package_manager, self.package_manager_cmd = self.detect_package_manager()
        if not self.package_manager:
            self.log("Cannot proceed without a detected package manager", "ERROR")
            self.write_log()
            return False
        
        # Step 3: Parse cpanfile
        if not self.parse_cpanfile():
            self.write_log()
            return False
        
        # Step 4: Get user confirmation
        if not self.get_user_confirmation():
            self.write_log()
            return False
        
        # Step 5: Install modules
        success = self.install_modules(dry_run=dry_run)
        
        # Step 6: Write log
        self.write_log()
        
        return success


def main():
    """Main entry point."""
    # Check root privileges first
    check_root_privileges()
    
    parser = argparse.ArgumentParser(
        description='Find and parse cpanfile, then install Perl modules',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  sudo %(prog)s                          # Look for cpanfile in current directory
  sudo %(prog)s /path/to/directory       # Look for cpanfile in specified directory
  sudo %(prog)s /path/to/cpanfile        # Use specified cpanfile directly
  sudo %(prog)s --log-file install.log   # Log output to file
  sudo %(prog)s --dry-run                # Show what would be installed without installing
        """
    )
    
    parser.add_argument(
        'path',
        nargs='?',
        help='Path to cpanfile or directory containing cpanfile'
    )
    parser.add_argument(
        '--log-file',
        help='Log output to specified file'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be installed without actually installing'
    )
    
    args = parser.parse_args()
    
    # Create installer
    installer = CpanModuleInstaller(log_file=args.log_file)
    
    # Run installer
    success = installer.run(specified_path=args.path, dry_run=args.dry_run)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
