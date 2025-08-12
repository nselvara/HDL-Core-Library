--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the SPI TX module.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

-- vunit: run_all_in_same_sim

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


entity tb_spi_tx is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_spi_tx is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant SIMULATION_TIMEOUT_TIME: time := 1 ms;
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant SYS_CLK_FREQUENCY: real := real(50e6);
    constant SYS_CLK_PHASE: time := 0 fs;

    signal spi_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant SPI_CLK_POLARITY: bit := '0';
    constant SPI_CLK_PHASE: bit := '0';
    constant CONTROLLER_AND_NOT_PERIPHERAL: boolean := true;
    constant MSB_FIRST_AND_NOT_LSB: boolean := true;
    constant DATA_WIDTH: positive := 8;
    constant CHIP_COUNT: positive := 8;

    package spi_pkg_constrained is new work.spi_pkg
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        );
    use spi_pkg_constrained.all;

    signal spi_clk: std_ulogic := '0';
    signal rst_n: std_ulogic := '1';

    signal selected_chips: std_ulogic_vector(CHIP_COUNT - 1 downto 0) := (others => '0');

    signal tx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal tx_data_valid: std_ulogic := '0';

    signal spi_clk_out: std_ulogic;
    signal serial_data_out: std_logic;
    signal spi_chip_select_n: std_ulogic_vector(CHIP_COUNT - 1 downto 0);

    signal tx_is_ongoing: std_ulogic;
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK Generation
    ------------------------------------------------------------
    generate_advanced_clock(spi_clk, SYS_CLK_FREQUENCY, SYS_CLK_PHASE, spi_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- VUnit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_spi_tx");

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
        variable expected_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable expected_spi_chip_select_n: std_ulogic_vector(CHIP_COUNT - 1 downto 0);

        procedure wait_spi_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(spi_clk);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure wait_tx_spi_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until tx_active_edge(spi_clk, SPI_CLK_POLARITY, SPI_CLK_PHASE);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure wait_chip_select_n_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until active_edge_chip_select_n_assertion(spi_clk, SPI_CLK_POLARITY);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure test_reset_behavior is begin
            info("1.0) Testing reset behavior");

            rst_n <= '1';
            tx_data_valid <= '0';
            selected_chips <= (others => '0');
            tx_data <= (others => '0');
            expected_spi_chip_select_n := (others => '1');
            wait_spi_clk_cycles(1);

            rst_n <= '0';
            wait_spi_clk_cycles(1);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "tx_is_ongoing - TX should be inactive during reset");
            check_equal(got => serial_data_out, expected => 'Z', msg => "serial_data_out - Serial data should be high-Z during reset");
            check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "spi_chip_select_n - Chip selects should be inactive during reset");

            rst_n <= '1';
            wait_spi_clk_cycles(1);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should remain inactive after reset");

            info("Reset behavior test passed" & LF);
        end procedure;

        procedure test_single_word_transmission is begin
            info("2.0) Testing single word transmission");

            expected_data := random.RandSlv(Size => DATA_WIDTH);

            tx_data <= expected_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "tx_is_ongoing - TX should be active");
            tx_data_valid <= '0';
            wait_spi_clk_cycles(1);

            wait_chip_select_n_cycles(1);
            check_equal(got => spi_chip_select_n, expected => not selected_chips, msg => "spi_chip_select_n - Chip select should be active");

            wait_tx_spi_clk_cycles(DATA_WIDTH);

            wait_spi_clk_cycles(1);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after transmission");
            check_equal(got => spi_chip_select_n, expected => std_ulogic_vector'(spi_chip_select_n'range => '1'), msg => "All chip selects should be inactive after transmission");

            info("Single word transmission test passed" & LF);
        end procedure;

        procedure test_multiple_chip_transmission is
            variable active_chip_select_n_index: natural range 0 to CHIP_COUNT - 1;
        begin
            info("3.0) Testing multiple chip transmission");

            expected_data := random.RandSlv(Size => DATA_WIDTH);

            tx_data <= expected_data;
            -- At least 2 chips should be selected for this test
            selected_chips <= random.RandSlv(Min => 3, Max => 2**selected_chips'length - 1, Size => selected_chips'length);
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "tx_is_ongoing - TX should be active");
            tx_data_valid <= '0';
            wait_spi_clk_cycles(1);
            wait_chip_select_n_cycles(1);

            for i in 0 to CHIP_COUNT - 1 loop
                if selected_chips(i) then
                    active_chip_select_n_index := i;
                else
                    next; -- Skip inactive chips
                end if;
                expected_spi_chip_select_n := (active_chip_select_n_index => '0', others => '1'); -- First chip should be selected
                check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "spi_chip_select_n - Chip select should be active");
                wait_tx_spi_clk_cycles(DATA_WIDTH);
            end loop;

            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after all chips have been transmitted");

            info("Multiple chip transmission test passed" & LF);
        end procedure;

        procedure test_back_to_back_transmissions is begin
            info("4.0) Testing back-to-back transmissions");

            expected_data := random.RandSlv(Size => DATA_WIDTH);

            -- First transmission
            tx_data <= expected_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            tx_data_valid <= '1';
            wait_spi_clk_cycles(1);
            tx_data_valid <= '0';

            -- Wait for almost complete
            wait_spi_clk_cycles(DATA_WIDTH - 2);

            check_equal(got => tx_is_ongoing, expected => '1', msg => "TX should still be active before second transmission");

            -- Second transmission before first completes
            expected_data := random.RandSlv(Size => DATA_WIDTH);
            tx_data <= expected_data;
            selected_chips <= (1 => '1', others => '0'); -- Select second chip
            tx_data_valid <= '1';
            wait_spi_clk_cycles(1);
            tx_data_valid <= '0';

            -- Wait for both transmissions
            wait_spi_clk_cycles(DATA_WIDTH);

            wait_spi_clk_cycles(1);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after all transmissions");

            info("Back-to-back transmissions test passed" & LF);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- NOTE: Don't remove, else VUnit will not run the test suite
        wait_spi_clk_cycles(1);

        while test_suite loop
            if run("test_reset_behavior") then
                test_reset_behavior;
            elsif run("test_single_word_transmission") then
                test_single_word_transmission;
            elsif run("test_multiple_chip_transmission") then
                test_multiple_chip_transmission;
            elsif run("test_back_to_back_transmissions") then
                test_back_to_back_transmissions;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------
    DUT: entity work.spi_tx
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            CONTROLLER_AND_NOT_PERIPHERAL => CONTROLLER_AND_NOT_PERIPHERAL,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB,
            ENABLE_INTERNAL_CLOCK_GATING => true,
            USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => false -- Use Xilinx clock gating instead of internal logic
        )
        port map (
            spi_clk_in => spi_clk,
            rst_n => rst_n,
            selected_chips => selected_chips,
            tx_data => tx_data,
            tx_data_valid => tx_data_valid,
            spi_clk_out => spi_clk_out,
            serial_data_out => serial_data_out,
            spi_chip_select_n => spi_chip_select_n,
            tx_is_ongoing => tx_is_ongoing
        );
    ------------------------------------------------------------
end architecture;
