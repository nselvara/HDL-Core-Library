--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the SPI RX module.
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


entity tb_spi_rx is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_spi_rx is
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
    constant MSB_FIRST_AND_NOT_LSB: boolean := true;
    constant DATA_WIDTH: positive := 8;

    package spi_pkg_constrained is new work.spi_pkg
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        );
    use spi_pkg_constrained.all;

    signal spi_clk: std_ulogic := '0';
    signal rst_n: std_ulogic := '1';

    signal serial_data_in: std_logic := '0';
    signal spi_chip_select_n: std_ulogic := '1';

    signal rx_data: std_ulogic_vector(data_range_t);
    signal rx_data_valid: std_ulogic;
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
        info("Starting tb_spi_rx");

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
        variable current_bit_index: data_range_t;
        variable expected_data: std_ulogic_vector(data_range_t);

        procedure wait_spi_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rx_active_edge(spi_clk, SPI_CLK_POLARITY, SPI_CLK_PHASE);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure transmit_and_check_data(data: std_ulogic_vector) is begin
            spi_chip_select_n <= '0';
            reset_bit_index(current_bit_index);

            for i in data_range_t loop
                serial_data_in <= data(current_bit_index);
                wait_spi_clk_cycles(1);

                if last_bit_index(current_bit_index) then
                    check_equal(got => rx_data_valid, expected => '1', msg => "rx_data_valid should be active after last bit");
                    check_equal(got => rx_data, expected => data, msg => "rx_data should match transmitted data");
                else
                    check_equal(got => rx_data_valid, expected => '0', msg => "rx_data_valid should be inactive during reception");
                end if;

                update_bit_index(current_bit_index);
            end loop;
        end procedure;

        procedure test_reset_behavior is begin
            info("1.0) Testing reset behavior");

            rst_n <= '1';
            spi_chip_select_n <= '1';
            serial_data_in <= '0';
            reset_bit_index(current_bit_index);
            wait_spi_clk_cycles(2);

            rst_n <= '0';
            wait_spi_clk_cycles(2);
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive during reset");

            rst_n <= '1';
            wait_spi_clk_cycles(2);
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should remain inactive after reset");

            info("Reset behavior test passed" & LF);
        end procedure;

        procedure test_single_byte_reception is begin
            info("2.0) Testing single byte reception");

            expected_data := random.RandSlv(Size => DATA_WIDTH);
            transmit_and_check_data(expected_data);

            spi_chip_select_n <= '1';
            wait_spi_clk_cycles(1);
            check_equal(got => rx_data_valid, expected => '0', msg => "rx_data_valid should be inactive after reception");

            info("Single byte reception test passed" & LF);
        end procedure;

        procedure test_continuous_reception is
            constant TEST_REPERTITIONS: natural := 1000;
        begin
            info("3.0) Testing continuous reception");

            for i in 0 to TEST_REPERTITIONS - 1 loop
                expected_data := random.RandSlv(Size => DATA_WIDTH);
                transmit_and_check_data(expected_data);
            end loop;

            spi_chip_select_n <= '1';
            wait_spi_clk_cycles(1);
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive after reception");

            info("Continuous reception test passed" & LF);
        end procedure;

        procedure test_interrupted_reception is begin
            info("4.0) Testing interrupted reception");

            expected_data := random.RandSlv(Size => DATA_WIDTH);
            reset_bit_index(current_bit_index);

            spi_chip_select_n <= '0';
            wait_spi_clk_cycles(1);

            for i in DATA_WIDTH - 1 downto DATA_WIDTH / 2 loop
                serial_data_in <= expected_data(i);
                wait_spi_clk_cycles(1);
                check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive during partial reception");
            end loop;

            spi_chip_select_n <= '1';
            wait_spi_clk_cycles(1);
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive after interrupted reception");

            transmit_and_check_data(expected_data);

            spi_chip_select_n <= '1';
            wait_spi_clk_cycles(1);

            info("Interrupted reception test passed" & LF);
        end procedure;

        procedure random_test is
            constant TEST_REPERTITIONS: natural := 1000;

            variable random_data: std_ulogic_vector(data_range_t);
            variable random_spi_chip_select_n: std_ulogic;
            variable spi_chip_select_n_reg: std_ulogic;
        begin
            info("5.0) Running random test");

            reset_bit_index(current_bit_index);
            spi_chip_select_n_reg := '1';

            for i in 0 to TEST_REPERTITIONS - 1 loop
                for j in data_range_t loop
                    random_data := random.RandSlv(Size => DATA_WIDTH);
                    random_spi_chip_select_n := random.DistSl(Weight => RESET_WEIGHT);
                    spi_chip_select_n <= random_spi_chip_select_n;

                    if random_spi_chip_select_n = '0' and spi_chip_select_n_reg = '1' then
                        expected_data := random_data;
                    end if;

                    serial_data_in <= expected_data(current_bit_index);
                    wait_spi_clk_cycles(1);

                    spi_chip_select_n_reg := spi_chip_select_n;

                    if random_spi_chip_select_n = '0' then
                        if last_bit_index(current_bit_index) then
                            check_equal(got => rx_data_valid, expected => '1', msg => "rx_data_valid should be active after last bit");
                            check_equal(got => rx_data, expected => expected_data, msg => "rx_data should match transmitted data");
                        else
                            check_equal(got => rx_data_valid, expected => '0', msg => "rx_data_valid should be inactive during reception");
                        end if;
                        update_bit_index(current_bit_index);
                    else
                        check_equal(got => rx_data_valid, expected => '0', msg => "rx_data_valid should be inactive when chip select is high");
                        reset_bit_index(current_bit_index);
                    end if;
                end loop;
            end loop;
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        --  NOTE: Don't remove, else VUnit will not run the test suite
        wait_spi_clk_cycles(1);

        while test_suite loop
            if run("test_reset_behavior") then
                test_reset_behavior;
            elsif run("test_single_byte_reception") then
                test_single_byte_reception;
            elsif run("test_continuous_reception") then
                test_continuous_reception;
            elsif run("test_interrupted_reception") then
                test_interrupted_reception;
            elsif run("random_test") then
                random_test;
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
    DUT: entity work.spi_rx
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        )
        port map (
            spi_clk => spi_clk,
            rst_n => rst_n,
            serial_data_in => serial_data_in,
            spi_chip_select_n => spi_chip_select_n,
            rx_data => rx_data,
            rx_data_valid => rx_data_valid
        );
    ------------------------------------------------------------
end architecture;
