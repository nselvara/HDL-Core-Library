[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

# Project name

Describe your project

The VHDL codes are tested with [VUnit framework's](https://vunit.github.io/) checks, [OSVVM](https://osvvm.org/) random features and simulated with [EDA Playground](https://www.edaplayground.com/) and/or [ModelSim](https://en.wikipedia.org/wiki/ModelSim).

## Minimum System Requirements

- **OS**: (Anything that can run the following)
  * **IDE**:
    - [`VSCode latest`](https://code.visualstudio.com/download) with following plugins:
      - [`Python`](https://marketplace.visualstudio.com/items?itemName=ms-python.python) by Microsoft
      - [`Pylance`](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance) by Microsoft
      - [`Draw.io`](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) by Henning Dieterichs
      - [`Draw.io Integration: WaveDrom plugin`](https://marketplace.visualstudio.com/items?itemName=nopeslide.vscode-drawio-plugin-wavedrom) by nopeslide
      - [`TerosHDL`](https://marketplace.visualstudio.com/items?itemName=teros-technology.teroshdl) by Teros Technology
      - [`VHDL-LS`](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls) by Henrik Bohlin (Deactivate the one provided by TerosHDL)
  * **VHDL Simulator**: (Anything that supports **VHDL-2008**)
  * **Script execution environment**:
    - `Python 3.11.4` to automatise testing via **VUnit**

## Initial Setup

### Clone repository

- Open terminal
- Run `git clone git@github.com:nselvara/eda_playground_mre.git`
- Run `cd eda_playground_mre`
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
> - Initializing the VUnit test runner
> - Loading `vunit_lib` correctly
> - Enabling procedures such as `check_equal`, `check_true`, etc.

> [!WARNING]
> However, EDA Playground will **not create any VHDL testbench** for you.  
> Therefore, you need to **manually create your own VHDL testbench file**:
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

**_:memo:_**: Don't forget to write the correct path to the ModelSim/QuestaSim folder

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

### Run Simulation Locally

This project uses **VUnit** for automated VHDL testbench simulation.  
The script [`test_runner.py`](ip/test_runner.py) acts as a wrapper, so you don’t need to deal with VUnit internals.

### Run Simulation Locally

This project uses **VUnit** for automated VHDL testbench simulation.  
The script [`test_runner.py`](ip/test_runner.py) acts as a wrapper, so you don’t need to deal with VUnit internals.

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
    compile_only=False,           # Only compile, don’t run simulations
    clean=False,                  # Clean before building
    debug=False,                  # Enable debug logging
    use_xilinx_libs=False,        # Add Xilinx simulation libraries
    use_intel_altera_libs=False   # Add Intel/Altera simulation libraries
)
```
