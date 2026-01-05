--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the single_port_ram module.
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


entity tb_single_port_ram is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string;
        SIMULATION_TIMEOUT_IN_MS: string
    );
end entity;

architecture tb of tb_single_port_ram is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant MINIMUM_SIMULATION_TIME_IN_MS: real := 1.2; -- Minimum time needed for all tests
    constant REQUESTED_SIMULATION_TIMEOUT_TIME: time := real'value(SIMULATION_TIMEOUT_IN_MS) * 1 ms;
    constant SIMULATION_TIMEOUT_TIME: time := maximum(REQUESTED_SIMULATION_TIMEOUT_TIME, MINIMUM_SIMULATION_TIME_IN_MS * 1 ms);
    constant ENABLE_DEBUG_PRINT: boolean := false;
    constant RANDOM_REPETITIONS: natural := 10;

    constant SYS_CLK_FREQUENCY: real := real(100e6);
    constant SYS_CLK_PHASE: time := 0 fs;

    signal sys_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant ADDRESS_WIDTH: positive := 8;
    constant DATA_WIDTH: positive := 8;

    signal sys_clk: std_ulogic := '0';
    signal sys_rst_n: std_ulogic := '1';
    signal address: unsigned(ADDRESS_WIDTH - 1 downto 0) := (others => '0');
    signal en: std_ulogic := '0';
    signal write_and_not_read: std_ulogic := '0';
    signal data_in: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal data_out: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK and RESET Generation
    ------------------------------------------------------------
    sys_clk_enable <= '1';
    generate_advanced_clock(sys_clk, SYS_CLK_FREQUENCY, SYS_CLK_PHASE, sys_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Vunit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_single_port_ram");

        if REQUESTED_SIMULATION_TIMEOUT_TIME < MINIMUM_SIMULATION_TIME_IN_MS * 1 ms then
            warning("Simulation timeout (" & SIMULATION_TIMEOUT_IN_MS & " ms) is less than minimum required (" & real'image(MINIMUM_SIMULATION_TIME_IN_MS) & " ms). Using minimum timeout instead.");
        end if;

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

        procedure wait_sys_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(sys_clk);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure restart_module is begin
            sys_rst_n <= '0';
            wait_sys_clk_cycles(1);
            sys_rst_n <= '1';
            wait_sys_clk_cycles(1);
        end procedure;

        procedure test_full_ram is begin
            info("1.0) test_full_ram");
            restart_module;

            en <= '1';

            for i in 0 to 2**address'length - 1 loop
                write_and_not_read <= '1';
                address <= to_unsigned(i, address'length);
                data_in <= std_ulogic_vector(to_unsigned(i mod 2**data_in'length, data_in'length));
                wait_sys_clk_cycles(1);

                write_and_not_read <= '0';
                wait_sys_clk_cycles(1);
                check_equal(data_out, data_in, "data_out");
            end loop;

            en <= '0';
            wait_sys_clk_cycles(1);
        end procedure;

        procedure test_random_addresses is begin
            info("2.0) test_random_addresses");
            restart_module;

            en <= '1';

            -- Arbitrary number of repeat
            for i in 0 to RANDOM_REPETITIONS - 1 loop
                write_and_not_read <= '1';
                address <= random.RandUnsigned(address'length);
                data_in <= random.RandSlv(data_in'length);
                wait_sys_clk_cycles(1);

                write_and_not_read <= '0';
                wait_sys_clk_cycles(1);
                check_equal(data_out, data_in, "data_out");
            end loop;

            en <= '0';
            wait_sys_clk_cycles(1);
        end procedure;

        procedure test_when_ram_deactivated is begin
            info("3.0) test_when_ram_deactivated");
            restart_module;

            en <= '0';

            -- Arbitrary number of repeat
            for i in 0 to RANDOM_REPETITIONS - 1 loop
                write_and_not_read <= '1';
                address <= random.RandUnsigned(address'length);
                data_in <= random.RandSlv(data_in'length);
                wait_sys_clk_cycles(1);

                write_and_not_read <= '0';
                wait_sys_clk_cycles(1);
                check_relation(data_out /= data_in, "data_out");
            end loop;

            en <= '0';
            wait_sys_clk_cycles(1);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_sys_clk_cycles(1);

        while test_suite loop
            if run("test_full_ram") then
                test_full_ram;
            elsif run("test_random_addresses") then
                test_random_addresses;
            elsif run("test_when_ram_deactivated") then
                test_when_ram_deactivated;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    DuT: entity work.single_port_ram
        port map (
            sys_clk => sys_clk,
            sys_rst_n => sys_rst_n,
            en => en,
            write_and_not_read => write_and_not_read,
            address => address,
            write_data => data_in,
            read_data => data_out
        );
end architecture;
