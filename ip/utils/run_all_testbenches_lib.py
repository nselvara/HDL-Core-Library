# -*- coding: utf-8 -*-
"""
Entry point for VUnit-based simulation framework.
Author: N. Selvarajah
"""

from os import walk, getenv
from os.path import dirname, join
from pathlib import Path
from vunit import VUnit


def discover_hdl_files(root_dir, extensions=(".vhd", ".vhdl", ".v"), ignore_pattern='~'):
    """
    Recursively find HDL source files, filtering out unwanted patterns.
    """
    return [
        join(path, file)
        for path, _, files in walk(root_dir)
            for file in files
                if file.endswith(extensions) and ignore_pattern not in file
    ]

def setup_vunit_environment(testbench_glob="**", gui_enabled=False, compile_only=False, clean_run=False, debug=False):
    """
    Set up the VUnit project with basic options and source discovery.
    """
    import sys
    args = sys.argv[1:]

    args.extend(["-p", "1", testbench_glob])
    if gui_enabled:
        args.append("--gui")
    if compile_only:
        args.append("--compile")
    if clean_run:
        args.append("--clean")
    if debug:
        args.append("--log-level=debug")

    vu = VUnit.from_argv(argv=args)
    vu.add_vhdl_builtins()
    vu.add_osvvm()
    return vu

def configure_sim_options(vu, timeout_ms=0.5, use_xilinx_libs=False, use_intel_altera_libs=False):
    """
    Configure common simulation settings.
    """
    vu.set_generic("SIMULATION_TIMEOUT_IN_MS", str(timeout_ms), allow_empty=True)

    # Common ModelSim/QuestaSim simulation options
    sim_opts = ["-t 1ns", "-voptargs=+acc"]

    if use_intel_altera_libs:
        sim_opts += ["-L altera_mf_ver", "-L altera_lnsim_ver", "-L lpm_ver"]
    if use_xilinx_libs:
        sim_opts += ["-L unisims_ver", "-L unimacro_ver", "-L xpm", "-L secureip", "glbl"]
    if "questa_base" in getenv('VUNIT_MODELSIM_PATH'):
        # For Questa base optimization, enable simulation statistics, and print simulation statistics
        sim_opts += ["-qbase_tune", "-printsimstats", "-simstats"] 

    vu.set_sim_option("modelsim.vsim_flags", sim_opts)
    vu.set_sim_option("disable_ieee_warnings", True)
    
    # Add file to initialise the simulation when running in GUI mode
    current_directory_path = Path(__file__).resolve().parent
    wave_do_path = f"{current_directory_path}\\find_wave_file.do"
    vu.set_sim_option("modelsim.init_file.gui", wave_do_path, allow_empty=True)

def main(path=".", tb_pattern="**", timeout_ms=0.5, gui=False, compile_only=False, clean=False, debug=False, use_xilinx_libs=False, use_intel_altera_libs=False):
    vu = setup_vunit_environment(
        testbench_glob=tb_pattern,
        gui_enabled=gui,
        compile_only=compile_only,
        clean_run=clean,
        debug=debug
    )

    lib = vu.add_library("vunit_library")
    source_files = discover_hdl_files(path)
    lib.add_source_files(source_files, allow_empty=True)

    configure_sim_options(vu, timeout_ms, use_xilinx_libs, use_intel_altera_libs)

    # Start simulation
    try:
        vu.main()
    except SystemExit as exception:
        return exception.code
    return 0

class bcolours:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

if __name__ == "__main__":
    main()
