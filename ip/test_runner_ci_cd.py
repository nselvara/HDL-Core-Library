# -*- coding: utf-8 -*-
"""
CI/CD test runner for VUnit tests - Vanilla VHDL only.
This script runs tests without any vendor-specific libraries (Xilinx/Intel).
It uses only the behavioral/technology-independent implementations.
Author: N. Selvarajah
"""

import os
import sys

from vhdl_utils.run_all_testbenches_lib import main as run_all_testbenches_lib
from vhdl_utils.run_all_testbenches_lib import bcolours

def run_all_testbenches():
    """
    Run all testbenches using only vanilla VHDL (behavioral implementations).
    No vendor libraries (Xilinx/Intel) are used - perfect for CI/CD environments.
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
    print("Running with vanilla VHDL (behavioral implementations only)")
    print(f"Test path: {test_path}")
    print(f"CI Mode: {is_ci_mode}")
    if xunit_xml_path:
        print(f"XUnit XML output: {xunit_xml_path}")
    print()

    returncode = run_all_testbenches_lib(
        path=test_path,
        tb_pattern="**",
        timeout_ms=1.0,
        gui=False,
        compile_only=False,
        clean=False,
        debug=False,
        use_xilinx_libs=False,          # Disabled for CI/CD
        use_intel_altera_libs=False,    # Disabled for CI/CD
        excluded_list=["tb_pll.vhd", "pll.vhd", "tb_fifo_async.vhd", "fifo_async.vhd"],  # Exclude specific testbenches that require unisim library and fifo_async uses non-conformant VHDL statement
        xunit_xml=xunit_xml_path        # Forward the xunit-xml argument
    )

    print()
    print("=== CI/CD Test Results ===")
    print(
        f"HDL Tests: {bcolours.OKGREEN + 'Passed' if returncode == 0 else bcolours.FAIL + 'Failed'}{bcolours.ENDC}"
    )

    return returncode

if __name__ == "__main__":
    exit(run_all_testbenches())
