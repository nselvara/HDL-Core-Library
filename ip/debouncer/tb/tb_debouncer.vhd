--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the debouncer module.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

-- VUnit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.tb_utils.all;
use work.utils_pkg.all;


entity tb_debouncer is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_debouncer is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant SIMULATION_TIMEOUT_TIME: time := 10 ms;
    constant ENABLE_DEBUG_PRINT: boolean := false;

    signal clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant CLK_FREQUENCY: real := real(100e6); -- 100 MHz
    constant DEBOUNCE_SYNC_BITS: natural := 4; -- Small value for simulation time
    constant POLARITY: std_ulogic := '1';

    signal clk: std_ulogic := '0';
    signal input: std_ulogic := not POLARITY;
    signal output: std_ulogic;
    ------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK Generation
    ------------------------------------------------------------
    generate_advanced_clock(clk, CLK_FREQUENCY, 0 fs, clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- VUnit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_debouncer");

        if ENABLE_DEBUG_PRINT then
            show(display_handler, debug);
        end if;

        wait until simulation_done;
        info("Debouncer tests completed successfully!" & LF);

        test_runner_cleanup(runner);
        wait;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Checker
    ------------------------------------------------------------
    checker: process
        constant DEBOUNCE_WAIT_CYCLES: natural := 2**DEBOUNCE_SYNC_BITS + 2; -- Allow for debounce time plus some margin

        variable random: RandomPType;

        procedure wait_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(clk);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure test_initial_state is begin
            info("1.0) Testing initial state");

            -- Check that output starts at not POLARITY
            check_equal(output, not POLARITY, "Initial output should be not POLARITY");

            info("Initial state test passed" & LF);
        end procedure;

        procedure test_clean_transition is begin
            info("2.0) Testing clean transition");

            input <= POLARITY;

            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
            check_equal(output, POLARITY, "Output should change after stable input");

            input <= not POLARITY;

            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
            check_equal(output, not POLARITY, "Output should change back after stable input");

            info("Clean transition test passed" & LF);
        end procedure;

        procedure test_bouncy_transition is begin
            info("3.0) Testing bouncy transition");

            -- Start with input at not POLARITY
            input <= not POLARITY;
            wait_clk_cycles(5);

            -- Simulate bouncy transition with multiple changes
            input <= POLARITY;
            wait_clk_cycles(1);
            input <= not POLARITY;
            wait_clk_cycles(1);
            input <= POLARITY;
            wait_clk_cycles(1);
            input <= not POLARITY;
            wait_clk_cycles(1);
            input <= POLARITY; -- Final stable state

            check_equal(output, not POLARITY, "Output should not change during bouncy transition");

            wait_clk_cycles(2**DEBOUNCE_SYNC_BITS - 2);
            check_equal(output, not POLARITY, "Output should not change before debounce time");

            wait_clk_cycles(4);
            check_equal(output, POLARITY, "Output should change after debounce time");

            info("Bouncy transition test passed" & LF);
        end procedure;

        procedure test_partial_debounce is begin
            info("4.0) Testing partial debounce reset");

            input <= POLARITY;
            wait_clk_cycles(5);

            input <= not POLARITY;

            wait_clk_cycles(2**DEBOUNCE_SYNC_BITS - 1);
            input <= POLARITY;

            check_equal(output, POLARITY, "Output should not change when transition interrupted");

            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
            check_equal(output, POLARITY, "Output should remain stable when bounce returns to original state");

            info("Partial debounce test passed" & LF);
        end procedure;

        procedure test_rapid_transitions is begin
            info("5.0) Testing rapid transitions");

            -- Start with input at POLARITY
            input <= POLARITY;
            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);

            check_equal(output, POLARITY, "Starting state should be POLARITY");

            for i in 0 to 9 loop
                input <= not input;
                wait_clk_cycles(1);
            end loop;

            input <= not POLARITY;

            check_equal(output, POLARITY, "Output should not change during rapid transitions");

            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
            check_equal(output, not POLARITY, "Output should change after input stabilizes");

            info("Rapid transitions test passed" & LF);
        end procedure;

        procedure test_random_debouncer is
            variable bounce_amount: natural;
            variable random_repetitions: natural;
            variable random_input: std_ulogic;
            variable expected_output: std_ulogic;
        begin
            info("6.x) test_random_debouncer");

            bounce_amount := random.RandInt(10, 100);
            random_repetitions := random.RandInt(2, 5);

            info("6.1) test_random_debouncer");
            input <= '0';
            wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
            check_equal(output, '0', "output should be '0' when input is '0'");

            for j in 0 to random_repetitions - 1 loop
                info("6." & to_string(j) & "1" & ") test_random_debouncer");
                expected_output := output;

                for i in 0 to bounce_amount - 1 loop
                    input <= random.RandSlv(1)(1);
                    check_equal(output, expected_output, "output should be " & to_string(not POLARITY) & " when input is '0'");
                    wait_clk_cycles(1);
                    input <= random.RandSlv(1)(1);
                    check_equal(output, expected_output, "output should be " & to_string(not POLARITY) & " when input is '1'");
                    wait_clk_cycles(1);
                end loop;

                info("6." & to_string(j) & "2" & ") test_random_debouncer");
                random_input := random.RandSlv(1)(1);
                input <= random_input;
                wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
                check_equal(output, input, "output should be " & to_string(input) & " when input is " & to_string(input));

                info("6." & to_string(j) & "2" & ") test_random_debouncer");
                for i in 0 to bounce_amount - 1 loop
                    input <= random.RandSlv(1)(1);
                    check_equal(output, random_input, "output should be " & to_string(input) & " when input is " & to_string(input));
                    wait_clk_cycles(1);
                    input <= random.RandSlv(1)(1);
                    check_equal(output, random_input, "output should be " & to_string(input) & " when input is " & to_string(input));
                    wait_clk_cycles(1);
                end loop;

                info("6." & to_string(j) & "2" & ") test_random_debouncer");
                input <= not random_input;
                wait_clk_cycles(DEBOUNCE_WAIT_CYCLES);
                check_equal(output, input, "output should be '0' when input is '0'");
            end loop;

            info("Random debouncer test passed" & LF);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_clk_cycles(1);

        while test_suite loop
            if run("test_initial_state") then
                test_initial_state;
            elsif run("test_clean_transition") then
                test_clean_transition;
            elsif run("test_bouncy_transition") then
                test_bouncy_transition;
            elsif run("test_partial_debounce") then
                test_partial_debounce;
            elsif run("test_rapid_transitions") then
                test_rapid_transitions;
            elsif run("test_random_debouncer") then
                test_random_debouncer;
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
    DUT: entity work.debouncer
        generic map (
            DEBOUNCE_SYNC_BITS => DEBOUNCE_SYNC_BITS,
            POLARITY => POLARITY
        )
        port map (
            clk_in => clk,
            input => input,
            output => output
        );
    ------------------------------------------------------------
end architecture;
