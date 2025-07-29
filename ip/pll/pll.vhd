--!
--! @author:    N. Selvarajah
--! @brief:     This module describes a clock generator block.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

entity pll is
    generic (
        IN_CLK_PERIOD_PS: real := 8.0;
        CLK_MULTIPLY: positive := 8;
        CLK_DIVIDE: positive := 1;
        OUT_CLK_0_DIVIDE: positive := 8;
        OUT_CLK_1_DIVIDE: positive := 40
    );
    port (
        in_clk: in std_ulogic;
        out_clk_0: out std_ulogic;
        out_clk_1: out std_ulogic;
        locked: out std_ulogic
    );
end entity;

library unisim;
use unisim.vcomponents.all;

architecture xilinx_behavioural of pll is
    signal out_clk_f_b: std_ulogic;
    signal pll_clks_0: std_ulogic;
    signal pll_clks_1: std_ulogic;
begin
    pll_inst: PLLE2_BASE
        generic map (
            CLKIN1_PERIOD => IN_CLK_PERIOD_PS,
            CLKFBOUT_MULT => CLK_MULTIPLY,
            CLKOUT0_DIVIDE => OUT_CLK_0_DIVIDE,
            CLKOUT1_DIVIDE => OUT_CLK_1_DIVIDE,
            DIVCLK_DIVIDE => CLK_DIVIDE
        )
        port map (
            pwrdwn => '0',
            rst => '0',
            clkin1 => in_clk,
            clkfbin => out_clk_f_b,
            clkfbout => out_clk_f_b,
            clkout0 => pll_clks_0,
            clkout1 => pll_clks_1,
            locked => locked
        );

    clk_0_inst: BUFG
        port map (
            I => pll_clks_0,
            O => out_clk_0
        );

    clk_1_inst: BUFG
        port map (
            I => pll_clks_1,
            O => out_clk_1
        );
end architecture;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture intel_behavioural of pll is
begin
    pll_inst: altclklock
        generic map (
            inclock_period => positive(IN_CLK_PERIOD_PS),
            inclock_settings => "UNUSED",
            valid_lock_cycles => 2,
            invalid_lock_cycles => 2,
            operation_mode => "NORMAL",
            clock0_boost => CLK_MULTIPLY,
            clock0_divide => CLK_DIVIDE,
            clock0_settings => "UNUSED",
            clock0_time_delay => "0",
            outclock_phase_shift => 0,
            intended_device_family => "Arria 10",
            lpm_type => "altclklock"
        )
        port map (
            inclock => in_clk,
            inclocken => '1',
            fbin => out_clk_0, -- Feedback clock
            clock0 => out_clk_0,
            clock1 => out_clk_1,
            locked => locked
        );
end architecture;
