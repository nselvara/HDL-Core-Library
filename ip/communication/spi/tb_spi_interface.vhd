--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the SPI interface module.
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


entity tb_spi_interface is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_spi_interface is
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

    signal spi_clk_in: std_ulogic := '0';
    signal rst_n: std_ulogic := '1';

    signal selected_chips: std_ulogic_vector(CHIP_COUNT - 1 downto 0) := (others => '0');

    signal tx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal tx_data_valid: std_ulogic := '0';

    signal rx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rx_data_valid: std_ulogic;

    signal spi_clk_out: std_ulogic;
    signal serial_data_out: std_logic;
    signal serial_data_in: std_ulogic := '0';
    signal spi_chip_select_n: std_ulogic_vector(CHIP_COUNT - 1 downto 0);

    signal tx_is_ongoing: std_ulogic;

    ------------------------------------------------------------
    -- Testbench signals
    ------------------------------------------------------------
    signal serial_data_out_expected: std_logic;
    signal serial_data_out_internal: std_logic;
    signal spi_chip_select_n_expected: spi_chip_select_n'subtype;
    signal spi_chip_select_n_internal: spi_chip_select_n'subtype;

    signal loopback_enabled: boolean := false;
    ------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK Generation
    ------------------------------------------------------------
    generate_advanced_clock(spi_clk_in, SYS_CLK_FREQUENCY, SYS_CLK_PHASE, spi_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Loopback logic for testing full-duplex communication
    ------------------------------------------------------------
    serial_data_in <= std_ulogic(serial_data_out) when loopback_enabled else '0';
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Expected outputs alignment
    ------------------------------------------------------------
    expected_serial_data_out_and_chip_select_alignment: block
        signal spi_chip_select_n_assertion: spi_chip_select_n'subtype;
        signal spi_chip_select_n_deassertion: spi_chip_select_n'subtype;
    begin
        serial_data_out_alignment: case SPI_CLK_POLARITY & SPI_CLK_PHASE generate
            when "00" | "11" =>
                alignment: process (spi_clk_in)
                begin
                    if falling_edge(spi_clk_in) then
                        serial_data_out_expected <= serial_data_out_internal;
                    end if;
                end process;
            when "01" =>
                postpone: process (spi_clk_in)
                begin
                    if rising_edge(spi_clk_in) then
                        serial_data_out_expected <= serial_data_out_internal;
                    end if;
                end process;
            when "10" =>
                pass_through: serial_data_out_expected <= serial_data_out_internal;
        end generate;

        chip_select_n_driver: if CONTROLLER_AND_NOT_PERIPHERAL generate
            spi_chip_select_n_alignment: case SPI_CLK_POLARITY generate
                when '0' =>
                    alignment: process (spi_clk_in)
                    begin
                        if falling_edge(spi_clk_in) then
                            spi_chip_select_n_assertion <= spi_chip_select_n_internal;
                        elsif rising_edge(spi_clk_in) then
                            spi_chip_select_n_deassertion <= spi_chip_select_n_internal;
                        end if;
                    end process;
                when '1' =>
                    alignment: process (spi_clk_in)
                    begin
                        pass_through: spi_chip_select_n_assertion <= spi_chip_select_n_internal;

                        if falling_edge(spi_clk_in) then
                            spi_chip_select_n_deassertion <= spi_chip_select_n_internal;
                        end if;
                    end process;
            end generate;

            spi_chip_select_n_expected <= spi_chip_select_n_assertion and spi_chip_select_n_deassertion;
        end generate;
    end block;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- VUnit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_spi_interface");

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
        variable expected_tx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable expected_rx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable expected_spi_chip_select_n: spi_chip_select_n'subtype;

        procedure wait_spi_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until rising_edge(spi_clk_in);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure wait_tx_spi_clk_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until tx_active_edge(spi_clk_in, SPI_CLK_POLARITY, SPI_CLK_PHASE);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure wait_chip_select_n_cycles(cycles: natural) is begin
            for i in 0 to cycles - 1 loop
                wait until active_edge_chip_select_n_assertion(spi_clk_in, SPI_CLK_POLARITY);
            end loop;
            wait for PROPAGATION_TIME;
        end procedure;

        procedure test_reset_behavior is begin
            info("1.0) Testing reset behavior");

            rst_n <= '1';
            tx_data_valid <= '0';
            selected_chips <= (others => '0');
            tx_data <= (others => '0');
            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            -- Apply reset
            rst_n <= '0';
            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive during reset");
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive during reset");

            -- Release reset
            rst_n <= '1';
            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should remain inactive after reset");
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should remain inactive after reset");

            info("Reset behavior test passed" & LF);
        end procedure;

        procedure test_tx_only_operation is begin
            info("2.0) Testing TX-only operation");

            expected_tx_data := random.RandSlv(DATA_WIDTH);
            loopback_enabled <= false;

            -- Set up transmission
            tx_data <= expected_tx_data;
            tx_data_valid <= '1';
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            expected_spi_chip_select_n := (0 => '0', others => '1'); -- Only first chip should be selected
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "TX should be active");
            wait_chip_select_n_cycles(1);
            tx_data_valid <= '0';

            check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "Chip select should be active");

            -- Wait for transmission to complete
            wait_spi_clk_cycles(DATA_WIDTH + 2);

            -- Check transmission ended
            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after transmission");
            check_equal(got => and(spi_chip_select_n), expected => '1', msg => "All chip selects should be inactive after transmission");

            info("TX-only operation test passed" & LF);
        end procedure;

        procedure test_full_duplex_operation is begin
            info("3.0) Testing full-duplex operation (loopback)");

            expected_tx_data := random.RandSlv(DATA_WIDTH);
            expected_rx_data := expected_tx_data;

            -- Enable loopback to connect MOSI to MISO
            loopback_enabled <= true;

            -- Set up transmission
            tx_data <= expected_tx_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            expected_spi_chip_select_n := (0 => '0', others => '1'); -- Only first chip should be selected
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "TX should be active");
            wait_chip_select_n_cycles(1);
            tx_data_valid <= '0';

            -- Wait for transmission to complete
            wait_spi_clk_cycles(DATA_WIDTH);

            -- Check reception
            check_equal(got => rx_data_valid, expected => '1', msg => "RX data valid should be active after reception");
            check_equal(got => rx_data, expected => expected_rx_data, msg => "Received data should match transmitted data in loopback mode");

            -- Disable loopback
            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            info("Full-duplex operation test passed" & LF);
        end procedure;

        procedure test_multiple_single_transfers is
            constant REPETITION_COUNT: positive := 10; -- Number of repetitions for each transfer
        begin
            info("4.0) Testing multiple single transfers");

            loopback_enabled <= true;

            for i in 0 to REPETITION_COUNT - 1 loop
                expected_tx_data := random.RandSlv(DATA_WIDTH);
                tx_data <= expected_tx_data;
                selected_chips <= (0 => '1', others => '0'); -- Select first chip
                tx_data_valid <= '1';
                wait until tx_is_ongoing;
                check_equal(got => tx_is_ongoing, expected => '1', msg => "TX should be active");
                wait_chip_select_n_cycles(1);
                tx_data_valid <= '0';

                wait_spi_clk_cycles(DATA_WIDTH);

                check_equal(got => rx_data_valid, expected => '1', msg => "RX data valid should be active after reception");
                check_equal(got => rx_data, expected => expected_tx_data, msg => "First received data should match in loopback mode");
            end loop;

            -- Disable loopback
            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            info("Multiple transfers test passed" & LF);
        end procedure;

        procedure test_multi_chip_transfers is
            variable active_chip_select_n_index: natural range 0 to CHIP_COUNT - 1;
        begin
            info("5.0) Testing multi-chip transfers");

            loopback_enabled <= true;

            expected_tx_data := random.RandSlv(DATA_WIDTH);
            tx_data <= expected_tx_data;
            -- At least 2 chips should be selected for this test
            selected_chips <= random.RandSlv(Min => 3, Max => 2**selected_chips'length - 1, Size => selected_chips'length);
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "TX should be active");
            tx_data_valid <= '0';

            for i in 0 to CHIP_COUNT - 1 loop
                if selected_chips(i) then
                    active_chip_select_n_index := i;
                else
                    next; -- Skip inactive chips
                end if;

                wait_chip_select_n_cycles(1);

                expected_spi_chip_select_n := (active_chip_select_n_index => '0', others => '1');
                check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "spi_chip_select_n - Chip select should be active");
                wait_tx_spi_clk_cycles(DATA_WIDTH);
            end loop;

            -- Disable loopback
            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            info("Multi-chip transfers test passed" & LF);
        end procedure;

        procedure test_tx_data_correctness is
            constant TRANSMISSION_COUNT: positive := 5; -- Number of transmissions to test
            variable bit_index: natural; -- For loop's direction can't be changed easily, thus, we use a variable
            variable active_chip_count: natural;
            variable active_chip_select_n_index: natural range 0 to CHIP_COUNT - 1;
        begin
            info("Test 6.0) Testing TX data correctness" & LF);

            info("6.1) Single chip, single word");
            expected_tx_data := random.RandSlv(Size => DATA_WIDTH);
            reset_bit_index(bit_index);

            tx_data <= expected_tx_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            check_equal(got => tx_is_ongoing, expected => '1', msg => "tx_is_ongoing - TX should be active");
            tx_data_valid <= '0';
            wait_chip_select_n_cycles(1);

            -- Check each bit transmission
            for i in 0 to DATA_WIDTH - 1 loop
                check_equal(got => serial_data_out, expected => expected_tx_data(bit_index), msg => "serial_data_out - Bit " & to_string(bit_index) & " should match expected data");
                wait_tx_spi_clk_cycles(1);
                update_bit_index(bit_index);
            end loop;

            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after transmission");

            info("6.2) Single chip, multiple words");

            selected_chips <= (1 => '1', others => '0'); -- Select second chip
            for word_idx in 0 to TRANSMISSION_COUNT - 1 loop
                reset_bit_index(bit_index);
                expected_tx_data := random.RandSlv(Size => DATA_WIDTH);
                tx_data <= expected_tx_data;
                tx_data_valid <= '1';
                wait until tx_is_ongoing;
                tx_data_valid <= '0';
                wait_chip_select_n_cycles(1);

                -- Check each bit transmission
                for i in 0 to DATA_WIDTH - 1 loop
                    check_equal(got => serial_data_out, expected => expected_tx_data(bit_index), msg => "serial_data_out - Word " & to_string(word_idx) & " Bit " & to_string(bit_index) & " should match expected data");
                    wait_tx_spi_clk_cycles(1);
                    update_bit_index(bit_index);
                end loop;
            end loop;

            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after all words");

            info("6.3) Multiple chips, single word each");
            selected_chips <= random.RandSlv(Min => 3, Max => 2**selected_chips'length - 1, Size => selected_chips'length);

            -- Count active chips
            active_chip_count := 0;

            expected_tx_data := random.RandSlv(Size => DATA_WIDTH);
            tx_data <= expected_tx_data;
            tx_data_valid <= '1';
            wait until tx_is_ongoing;
            tx_data_valid <= '0';
            wait_chip_select_n_cycles(1);

            for chip_idx in 0 to CHIP_COUNT - 1 loop
                if selected_chips(chip_idx) then
                    active_chip_select_n_index := chip_idx;
                else
                    next; -- Skip inactive chips
                end if;

                -- We can't just expect that only one chip is selected, as the previous chip might still be selected depending on the clock phase/polarity
                check_equal(got => spi_chip_select_n(chip_idx), expected => '0', msg => "spi_chip_select_n - Chip " & to_string(chip_idx) & " should be selected");

                reset_bit_index(bit_index);
                -- Check each bit transmission for this chip
                for j in 0 to DATA_WIDTH - 1 loop
                    check_equal(got => serial_data_out, expected => expected_tx_data(bit_index), msg => "serial_data_out - Chip " & to_string(chip_idx) & " Bit " & to_string(bit_index) & " should match expected data");
                    wait_tx_spi_clk_cycles(1);
                    update_bit_index(bit_index);
                end loop;
            end loop;

            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after all chips");

            info("6.4) Multiple chips, multiple words each" & LF);
            selected_chips <= (0 => '1', 2 => '1', others => '0'); -- Select chips 0 and 2

            for word_idx in 0 to TRANSMISSION_COUNT- 1 loop
                expected_tx_data := random.RandSlv(Size => DATA_WIDTH);
                tx_data <= expected_tx_data;
                tx_data_valid <= '1';
                wait until tx_is_ongoing;
                tx_data_valid <= '0';
                wait_chip_select_n_cycles(1);

                for chip_idx in 0 to CHIP_COUNT - 1 loop
                    if selected_chips(chip_idx) then
                        active_chip_select_n_index := chip_idx;
                    else
                        next; -- Skip inactive chips
                    end if;

                    -- We can't just expect that only one chip is selected, as the previous chip might still be selected depending on the clock phase/polarity
                    check_equal(got => spi_chip_select_n(chip_idx), expected => '0', msg => "spi_chip_select_n - Word " & to_string(word_idx) & " Chip " & to_string(chip_idx) & " should be selected");

                    reset_bit_index(bit_index);
                    -- Check each bit transmission for this chip and word
                    for bit_idx in 0 to DATA_WIDTH - 1 loop
                        check_equal(got => serial_data_out, expected => expected_tx_data(bit_index), msg => "serial_data_out - Word " & to_string(word_idx) & " Chip " & to_string(chip_idx) & " Bit " & to_string(bit_index) & " should match expected data");
                        wait_tx_spi_clk_cycles(1);
                        update_bit_index(bit_index);
                    end loop;
                end loop;
            end loop;

            wait_spi_clk_cycles(2);
            check_equal(got => tx_is_ongoing, expected => '0', msg => "TX should be inactive after all transmissions");

            info("TX data correctness test passed" & LF);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_spi_clk_cycles(1);

        while test_suite loop
            if run("test_reset_behavior") then
                test_reset_behavior;
            elsif run("test_tx_only_operation") then
                test_tx_only_operation;
            elsif run("test_full_duplex_operation") then
                test_full_duplex_operation;
            elsif run("test_multiple_single_transfers") then
                test_multiple_single_transfers;
            elsif run("test_multi_chip_transfers") then
                test_multi_chip_transfers;
            elsif run("test_tx_data_correctness") then
                test_tx_data_correctness;
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
    DUT: entity work.spi_interface
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            CONTROLLER_AND_NOT_PERIPHERAL => CONTROLLER_AND_NOT_PERIPHERAL,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB,
            ENABLE_INTERNAL_CLOCK_GATING => true,
            USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => false
        )
        port map (
            spi_clk_in => spi_clk_in,
            rst_n => rst_n,
            selected_chips => selected_chips,
            tx_data => tx_data,
            tx_data_valid => tx_data_valid,
            rx_data => rx_data,
            rx_data_valid => rx_data_valid,
            spi_clk_out => spi_clk_out,
            serial_data_out => serial_data_out,
            serial_data_in => serial_data_in,
            spi_chip_select_n => spi_chip_select_n,
            tx_is_ongoing => tx_is_ongoing
        );
    ------------------------------------------------------------
end architecture;
