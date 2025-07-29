# -*- coding: utf-8 -*-
"""
Run all testbenches in the project using VUnit.
It functions as a wrapper to not bother the user with the details of VUnit.
Author: N. Selvarajah
"""

from utils.run_all_testbenches_lib import main as run_all_testbenches_lib
from utils.run_all_testbenches_lib import bcolours

def run_all_testbenches():
    returncode = run_all_testbenches_lib(
        path="./ip/",
        tb_pattern="**",
        timeout_ms=1.0,
        gui=True,
        compile_only=False,
        clean=False,
        debug=False,
        use_xilinx_libs=False,
        use_intel_altera_libs=False
    )
    print(
        f"hdl_offline_tests: {bcolours.OKGREEN + 'Passed' if returncode == 0 else bcolours.FAIL + 'Failed'}{bcolours.ENDC}"
    )
    return returncode

if __name__ == "__main__":
    exit(run_all_testbenches())
