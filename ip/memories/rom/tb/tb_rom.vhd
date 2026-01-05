--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the ROM module.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.memories_pkg.all;
use work.tb_utils.all;

entity tb_rom is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string;
        SIMULATION_TIMEOUT_IN_MS: string
    );
end entity;

architecture tb of tb_rom is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant MINIMUM_SIMULATION_TIME_IN_MS: real := 1.5; -- Minimum time needed for test_full_rom (2^16 iterations)
    constant REQUESTED_SIMULATION_TIMEOUT_TIME: time := real'value(SIMULATION_TIMEOUT_IN_MS) * 1 ms;
    constant SIMULATION_TIMEOUT_TIME: time := maximum(REQUESTED_SIMULATION_TIMEOUT_TIME, MINIMUM_SIMULATION_TIME_IN_MS * 1 ms);
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant SYS_CLK_FREQUENCY: real := real(100e6);
    constant SYS_CLK_PHASE: time := 0 fs;

    signal sys_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant ADDRESS_WIDTH: positive := 16;
    constant DATA_WIDTH: positive := 8;

    signal sys_clk: std_ulogic := '0';
    signal sys_rst_n: std_ulogic := '1';
    signal address: unsigned(ADDRESS_WIDTH - 1 downto 0) := (others => '0');
    signal q: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
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
        info("Starting tb_rom");

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
        alias rom_reg_only_for_simulation is << signal .tb_rom.DuT.rom_reg_only_for_simulation : rom_t(0 to 2**ADDRESS_WIDTH - 1)(q'range) >>;

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

        procedure test_full_rom is
            -- Subtype doesn't work as it's based on external signal
            variable rom_reg_random: rom_t(0 to 2**ADDRESS_WIDTH - 1)(q'range);
        begin
            info("1.0) test_full_ram");
            restart_module;

            for i in rom_reg_random'range loop
                rom_reg_random(i) := random.RandSlv(rom_reg_random(i)'length);
            end loop;

            rom_reg_only_for_simulation <= force rom_reg_random;

            for i in rom_reg_random'range loop
                address <= to_unsigned(i, address'length);
                wait_sys_clk_cycles(1);
                check_equal(q, rom_reg_random(i), "q");
            end loop;

            wait_sys_clk_cycles(1);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_sys_clk_cycles(1);

        while test_suite loop
            if run("test_full_rom") then
                test_full_rom;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    DuT: entity work.rom
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MEM_INIT_FILE_PATH => "",
            SIMULATION_MODE => true
        )
        port map (
            sys_clk => sys_clk,
            sys_rst_n => sys_rst_n,
            address => address,
            q => q
        );
end architecture;
