--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the startup_reset module.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.tb_utils.all;

entity tb_reset_on_startup is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string;
        SIMULATION_TIMEOUT_IN_MS: string
    );
end entity;

architecture tb of tb_reset_on_startup is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant SIMULATION_TIMEOUT_TIME: time := real'value(SIMULATION_TIMEOUT_IN_MS) * 1 ms;
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant SYS_CLK_FREQUENCY: real := real(100e6);
    constant SYS_CLK_PHASE: time := 0 fs;
    constant RESET_TIME: time := 100 ns;

    constant RESET_TIME_IN_CLOCK_CYCLES: natural := natural(RESET_TIME / (1.0 / SYS_CLK_FREQUENCY) / 1 sec);

    signal clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    signal clk: std_ulogic;

    -- Array signals for multiple DUT instances
    type rst_polarity_array is array (0 to 1) of std_ulogic;
    constant RESET_POLARITIES: rst_polarity_array := ('0', '1');  -- Active low, Active high

    signal rst_in: rst_polarity_array;
    signal rst_out: rst_polarity_array;
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK and RESET Generation
    ------------------------------------------------------------
    clk_enable <= '1';
    generate_advanced_clock(clk, SYS_CLK_FREQUENCY, SYS_CLK_PHASE, clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Vunit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_lcd_controller");

        if ENABLE_DEBUG_PRINT then
            show(display_handler, debug);
        end if;

        wait until simulation_done;
        info("Simulation done, all tests passed!" & LF);

        test_runner_cleanup(runner);
        wait;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Checker
    ------------------------------------------------------------
    checker: process
        constant PROPAGATION_TIME: time := 1 ns;
        variable random: RandomPType;

        procedure wait_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(clk);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure test_startup_reset is
            constant ACTIVE_LOW_INDEX: natural := 0;   -- Active low DUT
            constant ACTIVE_HIGH_INDEX: natural := 1;  -- Active high DUT
        begin
            info("1.x) test_startup_reset (both active low and active high)");

            -- Set both inputs to their inactive states
            rst_in(ACTIVE_LOW_INDEX) <= '1';   -- Inactive for active low
            rst_in(ACTIVE_HIGH_INDEX) <= '0';  -- Inactive for active high

            -- Test startup reset period for both polarities simultaneously
            for i in 0 to RESET_TIME_IN_CLOCK_CYCLES - 1 loop
                check_equal(rst_out(ACTIVE_LOW_INDEX), '0', "1.1a) Active low rst_out is active during reset cycle " & to_string(i));
                check_equal(rst_out(ACTIVE_HIGH_INDEX), '1', "1.1b) Active high rst_out is active during reset cycle " & to_string(i));
                wait_clk_cycles(1);
            end loop;

            -- Both should be inactive after startup reset period
            check_equal(rst_out(ACTIVE_LOW_INDEX), '1', "1.2a) Active low rst_out is inactive after reset period");
            check_equal(rst_out(ACTIVE_HIGH_INDEX), '0', "1.2b) Active high rst_out is inactive after reset period");
            wait_clk_cycles(1);

            -- Test that they remain inactive for some random cycles
            for i in 0 to random.RandInt(0, 10) loop
                check_equal(rst_out(ACTIVE_LOW_INDEX), '1', "1.3a) Active low rst_out remains inactive after " & to_string(i) & " cycles");
                check_equal(rst_out(ACTIVE_HIGH_INDEX), '0', "1.3b) Active high rst_out remains inactive after " & to_string(i) & " cycles");
                wait_clk_cycles(1);
            end loop;

            -- Test external reset assertion (active states)
            rst_in(ACTIVE_LOW_INDEX) <= '0';   -- Active for active low
            rst_in(ACTIVE_HIGH_INDEX) <= '1';  -- Active for active high

            -- Should not be immediately active (1 cycle delay)
            check_equal(rst_out(ACTIVE_LOW_INDEX), '1', "1.4a) Active low rst_out is not immediately active when rst_in goes active");
            check_equal(rst_out(ACTIVE_HIGH_INDEX), '0', "1.4b) Active high rst_out is not immediately active when rst_in goes active");
            wait_clk_cycles(1);

            -- Now both should be active
            for i in 0 to random.RandInt(0, 10) loop
                check_equal(rst_out(ACTIVE_LOW_INDEX), '0', "1.5a) Active low rst_out is active after " & to_string(i) & " cycles");
                check_equal(rst_out(ACTIVE_HIGH_INDEX), '1', "1.5b) Active high rst_out is active after " & to_string(i) & " cycles");
                wait_clk_cycles(1);
            end loop;

            -- Release external reset (back to inactive states)
            rst_in(ACTIVE_LOW_INDEX) <= '1';   -- Inactive for active low
            rst_in(ACTIVE_HIGH_INDEX) <= '0';  -- Inactive for active high

            -- Should not be immediately inactive (1 cycle delay)
            check_equal(rst_out(ACTIVE_LOW_INDEX), '0', "1.6a) Active low rst_out is not immediately inactive when rst_in goes inactive");
            check_equal(rst_out(ACTIVE_HIGH_INDEX), '1', "1.6b) Active high rst_out is not immediately inactive when rst_in goes inactive");
            wait_clk_cycles(1);

            -- Now both should be inactive
            for i in 0 to random.RandInt(0, 10) loop
                check_equal(rst_out(ACTIVE_LOW_INDEX), '1', "1.7a) Active low rst_out is inactive after " & to_string(i) & " cycles");
                check_equal(rst_out(ACTIVE_HIGH_INDEX), '0', "1.7b) Active high rst_out is inactive after " & to_string(i) & " cycles");
                wait_clk_cycles(1);
            end loop;
        end procedure;

    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait for PROPAGATION_TIME;

        while test_suite loop
            if run("test_startup_reset") then
                test_startup_reset;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    -- Generate multiple DUT instances for different reset polarities
    gen_duts: for i in RESET_POLARITIES'range generate
        DuT: entity work.reset_on_startup
            generic map (
                RESET_TIME_IN_CLK_CYCLES => RESET_TIME_IN_CLOCK_CYCLES,
                RESET_POLARITY => RESET_POLARITIES(i)
            )
            port map (
                clk => clk,
                rst_in => rst_in(i),
                rst_out => rst_out(i)
            );
    end generate;
end architecture;
