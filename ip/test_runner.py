# -*- coding: utf-8 -*-
"""
Run all testbenches in the project using VUnit.
It functions as a wrapper to not bother the user with the details of VUnit.

WARNING: If your design uses Xilinx primitives (XPM, UNISIM, etc.),
you MUST set use_xilinx_libs=True to avoid "glbl" module errors.
See README.md for more details.

Author: N. Selvarajah
"""

import sys
import os

from vhdl_utils.run_all_testbenches_lib import main as run_all_testbenches_lib
from vhdl_utils.run_all_testbenches_lib import bcolours

def run_all_testbenches():
    returncode = run_all_testbenches_lib(
        path="./ip/",                 # Path where the HDL & tb files are located
        tb_pattern="**",              # Match all testbenches
        timeout_ms=1.0,               # Timeout in milliseconds
        gui=False,                    # Set to True to open ModelSim/QuestaSim GUI
        compile_only=False,           # Only compile, don't run simulations
        clean=False,                  # Clean before building
        debug=False,                  # Enable debug logging
        use_xilinx_libs=True,         # Add Xilinx simulation libraries, note set it true to load glbl module
        use_intel_altera_libs=False,  # Add Intel/Altera simulation libraries
        excluded_list=[],             # List of testbenches to exclude
        xunit_xml=None                # Output file for test results
    )
    print(
        f"hdl_offline_tests: {bcolours.OKGREEN + 'Passed' if returncode == 0 else bcolours.FAIL + 'Failed'}{bcolours.ENDC}"
    )
    return returncode

if __name__ == "__main__":
    exit(run_all_testbenches())
