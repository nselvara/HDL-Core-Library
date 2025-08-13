# -*- coding: utf-8 -*-
"""
CI/CD test runner for VUnit tests with basic vendor library support.
This script runs tests with basic Xilinx UNISIM library support for CI/CD environments.
It excludes complex primitives that require full vendor tool installations.
Author: N. Selvarajah
"""

import os
import sys

from vhdl_utils.run_all_testbenches_lib import main as run_all_testbenches_lib
from vhdl_utils.run_all_testbenches_lib import bcolours

def run_all_testbenches():
    """
    Run all testbenches with basic Xilinx UNISIM library support.
    Uses open-source UNISIM components for basic clock management and I/O.
    Excludes complex primitives (like PLLs) that require full vendor libraries.
    """

    # Detect if running in CI mode
    is_ci_mode = os.getenv('VUNIT_CI_MODE', 'false').lower() == 'true'

    # In CI mode, use current directory; otherwise use "./ip/"
    test_path = "./" if is_ci_mode else "./ip/"

    # Parse xunit-xml argument from command line
    xunit_xml_path = None
    if "--xunit-xml" in sys.argv:
        xunit_index = sys.argv.index("--xunit-xml")
        if xunit_index + 1 < len(sys.argv):
            xunit_xml_path = sys.argv[xunit_index + 1]

    print("=== CI/CD Test Runner ===")
    print("Running with NVC VHDL simulator + behavioral models")
    print("Strategy: VHDL behavioral models for Xilinx primitives (like PLLE2_BASE)")
    print("Note: NVC cannot directly use Verilog primitives in VHDL code")
    print(f"Test path: {test_path}")
    print(f"CI Mode: {is_ci_mode}")
    if xunit_xml_path:
        print(f"XUnit XML output: {xunit_xml_path}")
    print()

    excluded_list = [
        "tb_pll.vhd",  # Exclude PLL due to missing VHDL binding for PLLE2_BASE
        "pll.vhd",     # Exclude PLL due to missing VHDL binding for PLLE2_BASE
    ]

    returncode = run_all_testbenches_lib(
        path=test_path,
        tb_pattern="**",
        timeout_ms=1.0,
        gui=False,
        compile_only=False,
        clean=False,
        debug=False,
        use_xilinx_libs=True,
        use_intel_altera_libs=True,
        excluded_list=excluded_list,    # Using behavioral models for simulation
        xunit_xml=xunit_xml_path
    )

    print()
    print("=== CI/CD Test Results ===")
    print(
        f"HDL Tests: {bcolours.OKGREEN + 'Passed' if returncode == 0 else bcolours.FAIL + 'Failed'}{bcolours.ENDC}"
    )

    return returncode

if __name__ == "__main__":
    exit(run_all_testbenches())
