[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![VUnit Tests](https://github.com/nselvara/HDL-Core-Lib/workflows/VUnit%20Tests/badge.svg)](https://github.com/nselvara/HDL-Core-Lib/actions)

# HDL Core Library

A comprehensive collection of reusable VHDL IP cores for digital design, including memory modules, synchronisers, clock generators, and utility packages.

## 📦 Available IP Cores

### Memory Modules

- **Single Port RAM** - Configurable single-port memory with enable and reset functionality
- **Dual Port RAM** - True dual-port memory for concurrent read/write operations
- **Dual Clock RAM** - Asynchronous dual-port memory for clock domain crossing
- **Synchronous FIFO** - First-in-first-out buffer for single clock domain
- **Asynchronous FIFO** - FIFO with separate read/write clocks and gray code pointers
- **ROM** - Read-only memory with initialisation file support

### Synchronisation & Timing

- **FF Synchroniser** - Multi-stage flip-flop synchroniser for CDC
- **FF Synchroniser Vector** - Vector version of flip-flop synchroniser
- **Clock Generator** - Configurable clock generation module
- **Reset on Startup** - Power-on reset generation

### Input Processing

- **Debouncer** - Button/switch debouncing with configurable timing

### Utility Packages

- **utils_pkg** - Comprehensive utility functions (bit counting, one-hot detection, power operations)
- **tb_utils** - Testbench utilities for clock generation and common test procedures
- **memories_pkg** - Memory-related constants and types

## ✨ Key Features

- **MIT Licensed** - Permissive licensing for commercial and open-source use
- **VHDL-2008 Compatible** - Modern VHDL standard support
- **Comprehensive Testing** - Full VUnit test coverage for all modules
- **FPGA Optimised** - Designed for efficient synthesis on Xilinx and Intel FPGAs
- **Instance-Based Naming** - Clear port naming conventions (`write_data`/`read_data`)
- **Enhanced Interfaces** - Proper enable, reset, and control signal support

## 📁 Library Structure

```tree
ip/
├── pll/     # Clock generation modules
├── debouncer/          # Input debouncing
├── ff_synchroniser/    # Clock domain crossing synchronizers
├── memories/           # Memory IP cores
│   ├── fifo/          # FIFO implementations
│   ├── ram/           # RAM modules (single/dual port)
│   └── rom/           # ROM modules
├── reset_on_startup/   # Reset generation
└── utils/             # Utility packages and testbench helpers
```

## 🚀 Quick Start

### Using RAM Modules

```vhdl
-- Single Port RAM instantiation
ram_inst: entity work.single_port_ram
    port map (
        sys_clk => clk,
        sys_rst_n => rst_n,
        en => ram_enable,
        write_and_not_read => write_mode,
        address => ram_addr,
        write_data => data_to_write,
        read_data => data_from_ram
    );

-- Dual Port RAM instantiation
dual_ram_inst: entity work.dual_port_ram
    port map (
        sys_clk => clk,
        sys_rst_n => rst_n,
        en => ram_enable,
        write_enable => wr_en,
        read_enable => rd_en,
        write_address => wr_addr,
        read_address => rd_addr,
        write_data => wr_data,
        read_data => rd_data
    );
```

### Using Utility Functions

```vhdl
library work;
use work.utils_pkg.all;

-- Examples of utility function usage
signal data_vec: std_ulogic_vector(7 downto 0);
signal bit_count: natural;
signal is_power_of_two: boolean;

bit_count <= get_amount_of_state(data_vec, '1');  -- Count ones
is_power_of_two <= is_one_hot(data_vec);          -- Check if one-hot
```

The VHDL codes are tested with [VUnit framework's](https://vunit.github.io/) checks, [OSVVM](https://osvvm.org/) random features and simulated with [EDA Playground](https://www.edaplayground.com/) and/or [ModelSim](https://en.wikipedia.org/wiki/ModelSim).

## Minimum System Requirements

- **OS**: (Anything that can run the following)
  - **IDE**:
    - [`VSCode latest`](https://code.visualstudio.com/download) with following plugins:
      - [`Python`](https://marketplace.visualstudio.com/items?itemName=ms-python.python) by Microsoft
      - [`Pylance`](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance) by Microsoft
      - [`Draw.io`](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) by Henning Dieterichs
      - [`Draw.io Integration: WaveDrom plugin`](https://marketplace.visualstudio.com/items?itemName=nopeslide.vscode-drawio-plugin-wavedrom) by nopeslide
      - [`TerosHDL`](https://marketplace.visualstudio.com/items?itemName=teros-technology.teroshdl) by Teros Technology
      - [`VHDL-LS`](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls) by Henrik Bohlin (Deactivate the one provided by TerosHDL)
  - **VHDL Simulator**: (Anything that supports **VHDL-2008**)
  - **Script execution environment**:
    - `Python 3.11.4` to automatise testing via **VUnit**

## Initial Setup

### Clone repository

- Open terminal
- Run `git clone git@github.com:nselvara/HDL-Core-Lib.git`
- Run `cd HDL-Core-Lib`
- Run `code .` to open VSCode in the current directory

### Create Virtual Environment in VSCode

#### Via GUI

- Open VSCode
- Press `CTRL + Shift + P`
- Search for `Python: Create Environment` command
- Select `Venv`
- Select the latest Python version
- Select [`requirements.txt`](./ip/requirements.txt) file
- Wait till it creates and activates it automatically

#### Via Terminal

- Open VSCode
- Press `CTRL + J` if it's **Windows** or ``CTRL+` `` for **Linux** to open the terminal
- Run `python -m venv .venv` in Windows Terminal (CMD) or `python3 -m venv .venv` in Linux Terminal
- Run `.\.venv\Scripts\activate` on Windows or `source .venv/bin/activate` on Linux
- Run `pip install -r requirements.txt` to install all of the dependencies
- Click on `Yes` when the prompt appears in the right bottom corner

#### Additonal Info

For more info see page: [Python environments in VS Code](https://code.visualstudio.com/docs/python/environments)

## Running simulation

### Option 1: EDA Playground (Web-Based)

You can simulate this project on [EDA Playground](https://www.edaplayground.com/) without installing anything locally. Use the following settings:

- **Testbench + Design**: `VHDL`
- **Top entity**: `tb_test_entity` (or whatever your testbench entity is called)
- ✅ **Enable `VUnit`** (required to use VUnit checks like `check_equal`)

> [!WARNING]
> Enabling **VUnit** will automatically create a `testbench.py` file.
> **Do not delete this file**, as it is required for:
>
> - Initializing the VUnit test runner
> - Loading `vunit_lib` correctly
> - Enabling procedures such as `check_equal`, `check_true`, etc.

> [!WARNING]
> However, EDA Playground will **not create any VHDL testbench** for you.
> Therefore, you need to **manually create your own VHDL testbench file**:
>
> - Click the ➕ symbol next to the file list
> - Name it `tb.vhd` (or your own testbench name)
> - Paste your testbench VHDL code into it

- ✅ Select `OSVVM` under Libraries if your testbench uses OSVVM features
- **Tools & Simulators**: `Aldec Riviera Pro 2022.04` or newer
- **Compile Options**: `-2008`
- ✅ Check `Open EPWave after run`
- ✅ Check `Use run.do Tcl file` or `Use run.bash shell script` for more control (optional)

These settings ensure compatibility with your VUnit-based testbenches and allow waveform viewing through EPWave.

### Option 2: Local ModelSim/QuestaSim

#### Environment variables

Make sure the environment variable for ModelSim or QuestaSim is set, if not:

> [!NOTE]
> Don't forget to write the correct path to the ModelSim/QuestaSim folder

##### Linux

Open terminal and run either of the following commands:

```bash
echo "export VUNIT_MODELSIM_PATH=/opt/modelsim/modelsim_dlx/linuxpe" >> ~/.bashrc
# $questa_fe is the path to the folder where QuestaSim is installed
echo "export VUNIT_MODELSIM_PATH=\"$questa_fe/21.4/questa_fe/win64/\"" >> ~/.bashrc
```

Then restart the terminal or run `source ~/.bashrc` command.

#### Windows

Open PowerShell and run either of the following commands:

```bat
setx /m VUNIT_MODELSIM_PATH C:\modelsim_dlx64_2020.4\win64pe\
setx /m VUNIT_MODELSIM_PATH C:\intelFPGA_pro\21.4\questa_fe\win64\
```

This project uses **VUnit** for automated VHDL testbench simulation.
The script [`test_runner.py`](ip/test_runner.py) acts as a wrapper, so you don't need to deal with VUnit internals.

#### ⚙️ How to Run

1. **Open VSCode** (or any editor/terminal).
2. To run **all testbenches**, simply execute:

   ```bash
   ./.venv/Scripts/python.exe ./ip/test_runner.py
   ```

##### What the script does

- Uses `run_all_testbenches_lib` internally.
  - This hides the VUnit implementation
- Looks for testbenches in the `./ip/` folder.
- Runs all files matching `tb_*.vhd` (recursive pattern `**`).
- GUI can be enabled via `gui=True` in `test_runner.py`.

##### Optional Customization

You can change the following arguments in `test_runner.py`:

```python
run_all_testbenches_lib(
    path="./ip/",                 # Path where the HDL & tb files are located
    tb_pattern="**",              # Match all testbenches
    timeout_ms=1.0,               # Timeout in milliseconds
    gui=False,                    # Set to True to open ModelSim/QuestaSim GUI
    compile_only=False,           # Only compile, don't run simulations
    clean=False,                  # Clean before building
    debug=False,                  # Enable debug logging
    use_xilinx_libs=False,        # Add Xilinx simulation libraries
    use_intel_altera_libs=False,  # Add Intel/Altera simulation libraries
    excluded_list=[],             # List of testbenches to exclude
    xunit_xml="./test/res.xml"    # Output file for test results
)
```

## 🏭 Technology Support

Most IP cores in this library support multiple implementations:

- **Xilinx**: Optimised for Vivado/ISE, using Xilinx simulation libraries (e.g., XPM, UNISIM, UNIMACRO)
- **Intel/Altera**: Optimised for Quartus, using Intel/Altera simulation libraries (e.g., altera_mf)
- **Own/Behavioral**: Technology-independent VHDL-2008 behavioural implementation if possible

| IP Core                | Xilinx Implementation | Intel/Altera Implementation | Own/Behavioral Implementation |
| ---------------------- | --------------------- | --------------------------- | ----------------------------- |
| Single Port RAM        | Yes                   | Yes                         | Yes                           |
| Dual Port RAM          | Yes                   | Yes                         | Yes                           |
| Dual Clock RAM         | Yes                   | Yes                         | Yes                           |
| Synchronous FIFO       | Yes                   | Yes                         | Yes                           |
| Asynchronous FIFO      | Yes                   | Yes                         | Yes                           |
| ROM                    | Yes                   | Yes                         | Yes                           |
| FF Synchroniser        | Yes                   | Yes                         | Yes                           |
| FF Synchroniser Vector | Yes                   | Yes                         | Yes                           |
| Clock Generator (PLL)  | Yes (Xilinx PLL)      | Yes (Intel PLL)             | No                            |
| Debouncer              | Yes                   | Yes                         | Yes                           |
| Reset on Startup       | Yes                   | Yes                         | Yes                           |

> [!NOTE]
>
> - Xilinx simulation libraries (XPM, UNISIM, UNIMACRO) must be installed and available at:
>   - `/opt/xilinx/vivado/data/vhdl/src/` (Linux CI)
>   - `C:\Xilinx\Vivado\<version>\data\vhdl\src\` (Windows)
>   - XPM VHDL: `/opt/Xilinx/Vivado/<version>/data/ip/xpm/` or `C:\Xilinx\Vivado\<version>\data\ip\xpm\`
> - Intel/Altera simulation libraries (altera_mf, lpm, etc.) must be available at:
>   - `/opt/intelFPGA/<version>/quartus/eda/sim_lib/` (Linux CI)
>   - `C:/intelFPGA_pro/<version>/quartus/eda/sim_lib/` (Windows)
> - The technology-independent (own/behavioral) implementation is always available and does not require vendor libraries.
> - PLL modules are vendor-specific and do not have a pure behavioral implementation.

## 🤝 Contributing

Contributions are welcome! Please ensure:

- All new modules include comprehensive VUnit testbenches
- Code follows the established naming conventions
- Documentation is updated accordingly
- All tests pass before submitting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
