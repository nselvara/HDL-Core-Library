--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the ff_synchroniser module.
--! @note:      We only test the own_behavioural_ff_synchroniser architecture,
--!             as the xilinx_behavioural_ff_synchroniser is technology dependent, therefore already tested.
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

use work.utils_pkg.all;
use work.tb_utils.all;


entity tb_ff_synchroniser is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string;
        SIMULATION_TIMEOUT_IN_MS: string
    );
end entity;

architecture tb of tb_ff_synchroniser is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant SIMULATION_TIMEOUT_TIME: time := real'value(SIMULATION_TIMEOUT_IN_MS) * 1 ms;
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant SOURCE_CLK_FREQUENCY: real := real(100e6);
    constant DESTINATION_CLK_FREQUENCY: real := real(25e6);
    constant SYS_CLK_PHASE: time := 0 fs;

    signal source_clk_enable: std_ulogic := '1';
    signal destination_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant SYNC_SHIFT_FF: positive := 4;
    constant INIT_SYNC_FF: boolean := false;
    constant SIM_ASSERT_MSG: boolean := true;
    constant SRC_INPUT_REG: boolean := true;

    signal source_clk: std_ulogic := '0';
    signal destination_clk: std_ulogic := '0';
    signal source_domain: std_ulogic := '0';
    signal destination_domain_own: std_ulogic;
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK and RESET Generation
    ------------------------------------------------------------
    generate_advanced_clock(source_clk, SOURCE_CLK_FREQUENCY, SYS_CLK_PHASE, source_clk_enable);
    generate_advanced_clock(destination_clk, DESTINATION_CLK_FREQUENCY, SYS_CLK_PHASE, destination_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Vunit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_ff_synchroniser");

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
        variable random: RandomPType;

        procedure wait_source_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(source_clk);
            end loop;
        end procedure;

        procedure wait_destination_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(destination_clk);
            end loop;
        end procedure;

        procedure check_destination_domain_own(expected: std_ulogic) is begin
            check_equal(got => destination_domain_own, expected => expected, msg => "destination_domain_own");
        end procedure;

        procedure test_own_ff_synchroniser is
            variable BOUNCE_TIME: natural;
        begin
            info("1.x) test_own_ff_synchroniser");

            BOUNCE_TIME := random.RandInt(Min => 1, Max => 100);

            info("1.1) Let the synchronizer settle to a known state first");
            source_domain <= '0';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '0');

            info("1.2) destination_domain_own should be '1' when source_domain is '1'");
            source_domain <= '1';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '1');

            info("1.3) Test rapid bouncing - should eventually follow the last stable value");
            -- Start from known '1' state, then bounce rapidly
            for i in 0 to BOUNCE_TIME / 4 - 1 loop
                -- Quick bounce: 0->1->0->1
                source_domain <= '0';
                wait_source_clk_cycles(1);
                source_domain <= '1';
                wait_source_clk_cycles(1);
                source_domain <= '0';
                wait_source_clk_cycles(1);
                source_domain <= '1';
                wait_source_clk_cycles(1);
                -- Don't wait for destination clock - this creates real bouncing
            end loop;

            -- Now settle to '1' and verify it propagates
            source_domain <= '1';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '1');

            info("1.4) destination_domain_own should be '1' when source_domain settles to '1'");
            source_domain <= '1';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '1');

            info("1.5) Test rapid bouncing from high state");
            -- Start from known '1' state, then bounce rapidly
            for i in 0 to BOUNCE_TIME / 4 - 1 loop
                -- Quick bounce: 1->0->1->0
                source_domain <= '1';
                wait_source_clk_cycles(1);
                source_domain <= '0';
                wait_source_clk_cycles(1);
                source_domain <= '1';
                wait_source_clk_cycles(1);
                source_domain <= '0';
                wait_source_clk_cycles(1);
                -- Don't wait for destination clock - this creates real bouncing
            end loop;

            -- Now settle to '0' and verify it propagates
            source_domain <= '0';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '0');

            info("1.6) destination_domain_own should be '0' when source_domain settles to '0'");
            source_domain <= '0';
            wait_destination_clk_cycles(SYNC_SHIFT_FF + 1);
            check_destination_domain_own(expected => '0');
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_source_clk_cycles(1);

        while test_suite loop
            if run("test_own_ff_synchroniser") then
                test_own_ff_synchroniser;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    Own_Arch_DuT: entity work.ff_synchroniser(intel_behavioural_ff_synchroniser)
        generic map (
            SYNC_SHIFT_FF => SYNC_SHIFT_FF,
            INIT_SYNC_FF => INIT_SYNC_FF,
            SIM_ASSERT_MSG => SIM_ASSERT_MSG,
            SRC_INPUT_REG => SRC_INPUT_REG
        )
        port map (
            source_clk => source_clk,
            destination_clk => destination_clk,
            source_domain => source_domain,
            destination_domain => destination_domain_own
        );
end architecture;
