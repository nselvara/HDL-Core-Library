--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the clock generator module.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

-- VUnit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.tb_utils.all;
use work.utils_pkg.all;


entity tb_pll is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_pll is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant SIMULATION_TIMEOUT_TIME: time := 100 us; -- Need longer time to measure frequencies
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant IN_CLK_FREQUENCY: frequency_t := 100 MHz; -- 100MHz input clock frequency
    constant IN_CLK_PERIOD_PS: real := 10.0**12 / to_real(IN_CLK_FREQUENCY);

    constant CLK_MULTIPLY: positive := 8;
    constant CLK_DIVIDE: positive := 1;
    constant OUT_CLK_0_DIVIDE: positive := 4; -- Should result in 200MHz
    constant OUT_CLK_1_DIVIDE: positive := 10; -- Should result in 80MHz

    constant EXPECTED_OUT0_PERIOD: time := to_time(IN_CLK_FREQUENCY) * (real(OUT_CLK_0_DIVIDE) / real(CLK_MULTIPLY)) * real(CLK_DIVIDE);
    constant EXPECTED_OUT1_PERIOD: time := to_time(IN_CLK_FREQUENCY) * (real(OUT_CLK_1_DIVIDE) / real(CLK_MULTIPLY)) * real(CLK_DIVIDE);

    signal out_clk_0_edges: natural := 0;
    signal out_clk_1_edges: natural := 0;
    signal reset_out_clk_0: std_ulogic := '0';
    signal reset_out_clk_1: std_ulogic := '0';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    signal in_clk: std_ulogic := '0';
    signal in_clk_enable: std_ulogic := '1';
    signal out_clk_0: std_ulogic;
    signal out_clk_1: std_ulogic;
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK Generation
    ------------------------------------------------------------
    generate_advanced_clock(in_clk, to_real(IN_CLK_FREQUENCY), 0 fs, in_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- VUnit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_pll");

        if ENABLE_DEBUG_PRINT then
            show(display_handler, debug);
        end if;

        wait until simulation_done;
        info("Clock generator tests completed successfully!" & LF);

        test_runner_cleanup(runner);
        wait;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Edge counters
    ------------------------------------------------------------
    process (out_clk_0)
    begin
        if rising_edge(out_clk_0) then
            if reset_out_clk_0 then
                out_clk_0_edges <= 0;
            else
                out_clk_0_edges <= out_clk_0_edges + 1 when out_clk_0_edges < out_clk_0_edges'subtype'high else out_clk_0_edges;
            end if;
        end if;
    end process;

    process (out_clk_1)
    begin
        if rising_edge(out_clk_1) then
            if reset_out_clk_1 then
                out_clk_1_edges <= 0;
            else
                out_clk_1_edges <= out_clk_1_edges + 1 when out_clk_1_edges < out_clk_1_edges'subtype'high else out_clk_1_edges;
            end if;
        end if;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Checker
    ------------------------------------------------------------
    checker: process
        variable random: RandomPType;

        procedure wait_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(in_clk);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure test_clock_generation is
            variable start_time, end_time: time;
            variable measured_out0_period, measured_out1_period: time;
            variable total_cycles: natural := 1000;
        begin
            info("1.0) Testing clock generation and frequency");

            -- Reset counters
            reset_out_clk_0 <= '1';
            reset_out_clk_1 <= '1';
            wait_clk_cycles(10); -- Allow reset to propagate
            reset_out_clk_0 <= '0';
            reset_out_clk_1 <= '0';

            -- Wait for PLL lock (arbitrary time)
            wait for 1 us;

            -- Measure out_clk_0 frequency
            start_time := now;
            wait_clk_cycles(total_cycles);
            end_time := now;

            debug("Clock edges during " & to_string(total_cycles) & " input clock cycles:");
            debug("  out_clk_0 edges: " & to_string(out_clk_0_edges));
            debug("  out_clk_1 edges: " & to_string(out_clk_1_edges));

            measured_out0_period := (end_time - start_time) / out_clk_0_edges;
            measured_out1_period := (end_time - start_time) / out_clk_1_edges;

            debug("Expected out_clk_0 period: " & to_string(EXPECTED_OUT0_PERIOD));
            debug("Measured out_clk_0 period: " & to_string(measured_out0_period));
            debug("Expected out_clk_1 period: " & to_string(EXPECTED_OUT1_PERIOD));
            debug("Measured out_clk_1 period: " & to_string(measured_out1_period));

            -- Check ratios rather than absolute values (simulation timing can be imprecise)
            check(
                expr => is_relatively_equal(
                    real(out_clk_0_edges) / real(total_cycles),
                    real(CLK_MULTIPLY) / real(OUT_CLK_0_DIVIDE) * real(CLK_DIVIDE),
                    0.1
                ),
                msg => "out_clk_0 frequency ratio doesn't match expected value"
            );

            check(
                expr => is_relatively_equal(
                    real(out_clk_1_edges) / real(total_cycles),
                    real(CLK_MULTIPLY) / real(OUT_CLK_1_DIVIDE) * real(CLK_DIVIDE),
                    0.1
                ),
                msg => "out_clk_1 frequency ratio doesn't match expected value"
            );

            info("Clock generation test passed");
        end procedure;

        procedure test_clock_stability is
            variable edges_before_0, edges_after_0: natural;
            variable edges_before_1, edges_after_1: natural;
            constant TEST_CYCLES: natural := 1000;
        begin
            info("2.0) Testing clock stability");

            reset_out_clk_0 <= '1';
            reset_out_clk_1 <= '1';
            wait_clk_cycles(10); -- Allow reset to propagate
            reset_out_clk_0 <= '0';
            reset_out_clk_1 <= '0';

            -- Wait for PLL lock
            wait for 1 us;

            -- Capture initial edge counts
            edges_before_0 := out_clk_0_edges;
            edges_before_1 := out_clk_1_edges;

            -- Wait for a fixed number of input cycles
            wait_clk_cycles(TEST_CYCLES);

            -- Capture edge counts after first period
            edges_after_0 := out_clk_0_edges;
            edges_after_1 := out_clk_1_edges;

            reset_out_clk_0 <= '1';
            reset_out_clk_1 <= '1';
            wait_clk_cycles(10); -- Allow reset to propagate
            reset_out_clk_0 <= '0';
            reset_out_clk_1 <= '0';

            -- Wait for another fixed number of input cycles
            wait_clk_cycles(TEST_CYCLES);

            check_equal(
                got => out_clk_0_edges,
                expected => edges_after_0 - edges_before_0,
                msg => "Clock output 0 should produce consistent number of edges"
            );

            check_equal(
                got => out_clk_1_edges,
                expected => edges_after_1 - edges_before_1,
                msg => "Clock output 1 should produce consistent number of edges"
            );

            info("Clock stability test passed");
        end procedure;

    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_clk_cycles(1);

        while test_suite loop
            if run("test_clock_generation") then
                test_clock_generation;
            elsif run("test_clock_stability") then
                test_clock_stability;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
        wait;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------
    DUT: entity work.pll(xilinx_behavioural)
        generic map (
            IN_CLK_PERIOD_PS => IN_CLK_PERIOD_PS,
            CLK_MULTIPLY => CLK_MULTIPLY,
            CLK_DIVIDE => CLK_DIVIDE,
            OUT_CLK_0_DIVIDE => OUT_CLK_0_DIVIDE,
            OUT_CLK_1_DIVIDE => OUT_CLK_1_DIVIDE
        )
        port map (
            in_clk => in_clk,
            out_clk_0 => out_clk_0,
            out_clk_1 => out_clk_1
        );
    ------------------------------------------------------------
end architecture;
