--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the dual_port_ram module.
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


entity tb_dual_port_ram is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_dual_port_ram is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant SIMULATION_TIMEOUT_TIME: time := 3 ms;
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
    signal write_address: unsigned(ADDRESS_WIDTH - 1 downto 0) := (others => '0');
    signal read_address: unsigned(ADDRESS_WIDTH - 1 downto 0) := (others => '0');
    signal en: std_ulogic := '0';
    signal write_enable: std_ulogic := '0';
    signal read_enable: std_ulogic := '0';
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
        info("Starting tb_dual_port_ram");

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

            -- Check if data is after 1 clock cycle is readable
            for i in 0 to 2**write_address'length - 1 loop
                write_enable <= '1';
                read_enable <= '0';
                write_address <= to_unsigned(i, write_address'length);
                data_in <= std_ulogic_vector(to_unsigned(i mod 2**data_in'length, data_in'length));
                wait_sys_clk_cycles(1);

                write_enable <= '0';
                read_enable <= '1';
                read_address <= to_unsigned(i, read_address'length);
                wait_sys_clk_cycles(1);
                check_equal(got => data_out, expected => data_in, msg => "data_out");
            end loop;

            -- Check if data still existing after arbitrary number of read cycles
            for i in 0 to 2**write_address'length - 1 loop
                write_enable <= '0';
                read_enable <= '1';
                read_address <= to_unsigned(i, read_address'length);
                wait_sys_clk_cycles(1);
                check_equal(got => data_out, expected => std_ulogic_vector(to_unsigned(i mod 2**data_in'length, data_in'length)), msg => "data_out");
            end loop;

            en <= '0';
            write_enable <= '0';
            read_enable <= '0';
            wait_sys_clk_cycles(1);
        end procedure;

        procedure test_random_addresses is
            variable address_v: natural;
        begin
            info("2.0) test_random_addresses");
            restart_module;

            en <= '1';

            for i in 0 to 2**write_address'length - 1 loop
                write_enable <= '1';
                read_enable <= '0';
                write_address <= to_unsigned(i, write_address'length);
                data_in <= std_ulogic_vector(to_unsigned(i mod 2**data_in'length, data_in'length));
                wait_sys_clk_cycles(1);
            end loop;

            -- Arbitrary number of repeat
            for i in 0 to RANDOM_REPETITIONS - 1 loop
                address_v := random.RandInt(2**write_address'length - 1);
                read_address <= to_unsigned(address_v, write_address'length);
                write_enable <= '0';
                read_enable <= '1';
                wait_sys_clk_cycles(1);
                check_equal(got => data_out, expected => std_ulogic_vector(to_unsigned(address_v mod 2**data_in'length, data_in'length)), msg => "data_out");
            end loop;

            en <= '0';
            write_enable <= '0';
            read_enable <= '0';
            wait_sys_clk_cycles(1);
        end procedure;

        procedure test_when_ram_deactivated is
            constant UNKNOWN_DATA: data_out'subtype := (others => '-');
        begin
            info("3.0) test_when_ram_deactivated");
            restart_module;

            en <= '0';

            -- Arbitrary number of repeat
            for i in 0 to RANDOM_REPETITIONS - 1 loop
                write_enable <= '1';
                read_enable <= '0';
                write_address <= random.RandUnsigned(Size => write_address'length);
                read_address <= random.RandUnsigned(Size => read_address'length);
                data_in <= random.RandSlv(data_in'length);
                wait_sys_clk_cycles(1);

                write_enable <= '0';
                read_enable <= '1';
                wait_sys_clk_cycles(1);
                check_equal(got => data_out, expected => UNKNOWN_DATA, msg => "data_out");
            end loop;

            en <= '0';
            write_enable <= '0';
            read_enable <= '0';
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

    DuT: entity work.dual_port_ram
        port map (
            sys_clk => sys_clk,
            sys_rst_n => sys_rst_n,
            en => en,
            write_address => write_address,
            read_address => read_address,
            write_enable => write_enable,
            read_enable => read_enable,
            write_data => data_in,
            read_data => data_out
        );
end architecture;
