--!
--! @author:    N. Selvarajah
--! @brief:     This module describes a clock enable block with vendor-specific implementations.
--!
--! @note:      Clock gating differences between vendors:
--!             - Xilinx: Use BUFGCE (set USE_XILINX_CLK_GATE_AND_NOT_INTERNAL to true) for
--!               glitch-free clock gating on global clock networks.
--!             - Intel/Altera: Direct clock gating (clk_out <= clk_in when enable else '0')
--!               is NOT recommended for Intel devices. Instead:
--!               1. Set ENABLE_INTERNAL_CLOCK_GATING to false when using Intel devices.
--!               2. Use PLL enable pins at the clock source instead.
--!               3. Use register enable pins rather than gating the clock.
--!               4. Intel places clock enables globally but doesn't actually turn off
--!                  the clock analogously to Xilinx's BUFGCE.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity clock_enable is
    generic (
        -- Set to true for direct clock gating using the internal implementation.
        -- For Intel/Altera FPGAs, set to false and use PLL enable pins instead.
        ENABLE_INTERNAL_CLOCK_GATING: boolean := true;

        -- Set to true for Xilinx-specific global clock gating using BUFGCE.
        -- For Intel/Altera FPGAs, this should be false.
        USE_XILINX_CLK_GATE_AND_NOT_INTERNAL: boolean := false
    );
    port (
        clk_in: in std_ulogic;
        clk_enable: in std_ulogic;
        clk_out: out std_ulogic
    );
end entity;

architecture behavioural of clock_enable is
begin
    -- Internal clock gating enabled (true for Xilinx, not recommended for Intel)
    clk_gating: if ENABLE_INTERNAL_CLOCK_GATING generate
        -- Xilinx-specific implementation using BUFGCE
        xilinx_clk_gate: if USE_XILINX_CLK_GATE_AND_NOT_INTERNAL generate
            BUFGCE_inst: BUFGCE
                port map (
                    O => clk_out,
                    CE => clk_enable,
                    I => clk_in
                );
        -- Generic implementation (not recommended for Intel)
        else generate
            clk_out <= clk_in when clk_enable = '1' else '0';
        end generate;
    -- Pass-through mode (recommended for Intel/Altera)
    else generate
        clk_out <= clk_in; -- Clock passes through, rely on enable pins at registers instead
    end generate;
end architecture;
