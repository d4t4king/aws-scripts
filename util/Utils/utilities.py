#!/usr/bin/env python3

"""
A utility module for system-level environment verification.

This module provides common helper functions used across internal automation 
tooling to ensure execution environments meet required security and 
privilege specifications.
"""

import os
import sys
import pprint
from termcolor import cprint

class Utils:
    def __init__(self):
        pass

    @staticmethod
    def is_privileged_user() -> bool:
        """
        Checks if the current process has root/administrative privileges.

        This function determines if the script is being executed by the root user
        or with effective root capabilities on a Linux-based system by checking 
        the Effective User ID (EUID).

        Returns:
            bool: True if the process has root privileges (EUID 0), False otherwise.
            
        Example:
            >>> if not is_privileged_user():
            ...     print("Error: This script must be run as root.")
        """
        # On POSIX systems, root always has an UID of 0.
        # We check the effective UID to account for setuid binaries or 
        # elevated shells.
        try:
            return os.geteuid() == 0
        except AttributeError:
            # Fallback for non-POSIX platforms where geteuid() is not available.
            # In a production monorepo, this would likely log to a telemetry 
            # service like Google Cloud Logging or Meta's Scuba.
            return False

if __name__ == "__main__":
    # Internal testing/validation block
    if Utils.is_privileged_user():
        print("Running with elevated privileges.")
    else:
        print("Running as standard user.")
        sys.exit(1)
