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
use vunit_lib.queue_pkg.all;

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

    constant SPI_CLK_FREQUENCY: real := real(50e6);
    constant SPI_CLK_PHASE_SHIFT: time := 0 fs;

    constant TX_FIFO_WRITE_CLK_FREQUENCY: real := SPI_CLK_FREQUENCY; -- Same as SPI clock for simplicity
    constant TX_FIFO_WRITE_CLK_PHASE_SHIFT: time := 0 fs;
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

    -- FIFO interface signals
    signal tx_fifo_write_clk: std_ulogic := '0';
    signal tx_fifo_write_enable: std_ulogic := '0';
    signal tx_fifo_write_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal tx_fifo_write_blocked: std_ulogic;
    signal tx_fifo_full: std_ulogic;
    signal tx_fifo_empty: std_ulogic;
    signal tx_fifo_words_stored: natural range 0 to 2**4; -- 2**TX_FIFO_DEPTH_IN_BITS

    -- Streaming control
    signal tx_trigger: std_ulogic := '0';

    signal rx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rx_data_valid: std_ulogic;

    signal spi_clk_out: std_ulogic;
    signal serial_data_out: std_logic;
    signal serial_data_in: std_ulogic := '0';
    signal spi_chip_select_n: std_ulogic_vector(CHIP_COUNT - 1 downto 0);

    signal spi_busy: std_ulogic;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Testbench signals
    ------------------------------------------------------------
    signal serial_data_out_expected: std_logic;
    signal serial_data_out_internal: std_logic;
    signal spi_chip_select_n_expected: spi_chip_select_n'subtype;
    signal spi_chip_select_n_internal: spi_chip_select_n'subtype;

    signal loopback_enabled: boolean := false;

    signal spi_clk_enable: std_ulogic := '1';
    signal tx_fifo_write_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;

    signal received_queue: queue_t;
    signal spi_monitor_reset: std_ulogic := '1';
    ------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK Generation
    ------------------------------------------------------------
    generate_advanced_clock(spi_clk_in, SPI_CLK_FREQUENCY, SPI_CLK_PHASE_SHIFT, spi_clk_enable);
    generate_advanced_clock(tx_fifo_write_clk, TX_FIFO_WRITE_CLK_FREQUENCY, TX_FIFO_WRITE_CLK_PHASE_SHIFT, tx_fifo_write_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Loopback logic for testing full-duplex communication
    ------------------------------------------------------------
    serial_data_in <= std_ulogic(serial_data_out) when loopback_enabled else '0';
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- SPI Monitor Process - Acts as SPI Receiver using queues
    ------------------------------------------------------------
    spi_monitor: process (spi_clk_in)
        variable bit_index: natural range 0 to DATA_WIDTH - 1;
        variable captured_word: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable receiving: boolean := false;
    begin
        if rx_active_edge(spi_clk_in, SPI_CLK_POLARITY, SPI_CLK_PHASE) then
            if spi_monitor_reset then
                reset_bit_index(bit_index);
                receiving := false;
                received_queue <= new_queue;
            else
                if and(spi_chip_select_n) = '0' then
                    captured_word(bit_index) := serial_data_out;

                    if not receiving then
                        receiving := true;
                        reset_bit_index(bit_index);
                        debug("SPI Monitor: Started receiving");
                    end if;

                    -- Process complete word
                    if last_bit_index(bit_index) then
                        push(queue => received_queue, value => captured_word);
                        log("SPI Monitor: Captured word " & to_integer_string(captured_word));
                        reset_bit_index(bit_index);
                    else
                        update_bit_index(bit_index);
                    end if;
                else
                    receiving := false;
                    reset_bit_index(bit_index);
                end if;
            end if;
        end if;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Expected outputs alignment
    ------------------------------------------------------------
    expected_serial_data_out_and_chip_select_alignment: block
        signal spi_chip_select_n_assertion: spi_chip_select_n'subtype;
        signal spi_chip_select_n_deassertion: spi_chip_select_n'subtype;
    begin
        serial_data_out_alignment: process (all)
        begin
            if tx_active_edge(spi_clk_in, SPI_CLK_POLARITY, SPI_CLK_PHASE) then
                serial_data_out_expected <= serial_data_out_internal;
            end if;
        end process;

        chip_select_n_alignment: process (all)
        begin
            if active_edge_chip_select_n_assertion(spi_clk_in, SPI_CLK_POLARITY) then
                spi_chip_select_n_assertion <= spi_chip_select_n_internal;
            end if;

            if active_edge_chip_select_n_deassertion(spi_clk_in, SPI_CLK_POLARITY) then
                spi_chip_select_n_deassertion <= spi_chip_select_n_internal;
            end if;

            spi_chip_select_n_expected <= spi_chip_select_n_assertion and spi_chip_select_n_deassertion;
        end process;
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

        procedure reset_module is begin
            rst_n <= '0';
            wait_spi_clk_cycles(5);
            rst_n <= '1';
            wait_spi_clk_cycles(5);
        end procedure;

        procedure test_reset_behavior is begin
            info("1.0) Testing reset behavior");

            rst_n <= '1';
            tx_fifo_write_enable <= '0';
            tx_trigger <= '0';
            selected_chips <= (others => '0');
            tx_fifo_write_data <= (others => '0');

            spi_monitor_reset <= '1';
            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            -- Apply reset
            rst_n <= '0';
            wait_spi_clk_cycles(2);
            check_equal(got => spi_busy, expected => '1', msg => "TX should be inactive during reset");
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should be inactive during reset");

            -- Release reset
            rst_n <= '1';
            wait_spi_clk_cycles(2);
            check_equal(got => spi_busy, expected => '0', msg => "TX should remain inactive after reset");
            check_equal(got => rx_data_valid, expected => '0', msg => "RX data valid should remain inactive after reset");

            info("Reset behavior test passed" & LF);
        end procedure;

        procedure test_tx_only_operation is begin
            info("2.0) Testing TX-only operation with FIFO");

            reset_module;

            expected_tx_data := random.RandSlv(DATA_WIDTH);
            loopback_enabled <= false;

            -- Load data into FIFO
            tx_fifo_write_data <= expected_tx_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            spi_monitor_reset <= '1';

            expected_spi_chip_select_n := (0 => '0', others => '1'); -- Only first chip should be selected

            tx_fifo_write_enable <= '1';
            wait_spi_clk_cycles(1);
            tx_fifo_write_enable <= '0';

            wait until not tx_fifo_empty;
            wait_spi_clk_cycles(1);

            tx_trigger <= '1';
            wait_spi_clk_cycles(1);
            tx_trigger <= '0';

            wait until spi_busy;
            check_equal(got => spi_busy, expected => '1', msg => "TX should be active");
            wait_chip_select_n_cycles(4);

            check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "Chip select should be active");

            -- Wait for transmission to complete
            wait_spi_clk_cycles(DATA_WIDTH + 2);

            wait_spi_clk_cycles(2);
            check_equal(got => spi_busy, expected => '0', msg => "TX should be inactive after transmission");
            check_equal(got => and(spi_chip_select_n), expected => '1', msg => "All chip selects should be inactive after transmission");

            info("TX-only operation test passed" & LF);
        end procedure;

        procedure test_full_duplex_operation is begin
            info("3.0) Testing full-duplex operation (loopback) with FIFO");

            reset_module;

            expected_tx_data := random.RandSlv(DATA_WIDTH);
            expected_rx_data := expected_tx_data;

            spi_monitor_reset <= '1';
            loopback_enabled <= true;

            tx_fifo_write_data <= expected_tx_data;
            selected_chips <= (0 => '1', others => '0'); -- Select first chip
            expected_spi_chip_select_n := (0 => '0', others => '1'); -- Only first chip should be selected

            tx_fifo_write_enable <= '1';
            wait_spi_clk_cycles(1);
            tx_fifo_write_enable <= '0';

            wait until not tx_fifo_empty;
            wait_spi_clk_cycles(1);

            tx_trigger <= '1';
            wait_spi_clk_cycles(1);
            tx_trigger <= '0';

            wait until spi_busy;
            check_equal(got => spi_busy, expected => '1', msg => "TX should be active");
            wait_chip_select_n_cycles(4);

            wait_spi_clk_cycles(DATA_WIDTH);

            check_equal(got => rx_data_valid, expected => '1', msg => "RX data valid should be active after reception");
            check_equal(got => rx_data, expected => expected_rx_data, msg => "Received data should match transmitted data in loopback mode");

            wait until not spi_busy;

            loopback_enabled <= false;
            wait_spi_clk_cycles(1);

            info("Full-duplex operation test passed" & LF);
        end procedure;

        procedure test_multiple_single_transfers is
            constant REPETITION_COUNT: positive := 10; -- Number of repetitions for each transfer
        begin
            info("4.0) Testing multiple single transfers with FIFO");

            reset_module;

            spi_monitor_reset <= '1';
            loopback_enabled <= true;

            for i in 0 to REPETITION_COUNT - 1 loop
                expected_tx_data := random.RandSlv(DATA_WIDTH);

                tx_fifo_write_data <= expected_tx_data;
                selected_chips <= (0 => '1', others => '0'); -- Select first chip

                tx_fifo_write_enable <= '1';
                wait_spi_clk_cycles(1);
                tx_fifo_write_enable <= '0';

                wait until not tx_fifo_empty;
                wait_spi_clk_cycles(1);

                tx_trigger <= '1';
                wait_spi_clk_cycles(1);
                tx_trigger <= '0';

                wait until spi_busy;
                check_equal(got => spi_busy, expected => '1', msg => "TX should be active");
                wait_chip_select_n_cycles(4);

                wait_spi_clk_cycles(DATA_WIDTH);

                check_equal(got => rx_data_valid, expected => '1', msg => "RX data valid should be active after reception");
                check_equal(got => rx_data, expected => expected_tx_data, msg => "First received data should match in loopback mode");

                wait until not spi_busy;
            end loop;

            loopback_enabled <= false;
            wait_spi_clk_cycles(1);

            info("Multiple transfers test passed" & LF);
        end procedure;

        procedure test_multi_chip_transfers is
            variable active_chip_select_n_index: natural range 0 to CHIP_COUNT - 1;
            variable selected_chip_count: natural;
        begin
            info("5.0) Testing multi-chip transfers with FIFO");

            reset_module;

            spi_monitor_reset <= '1';
            loopback_enabled <= true;

            -- At least 2 chips should be selected for this test
            selected_chips <= random.RandSlv(Min => 3, Max => 2**selected_chips'length - 1, Size => selected_chips'length);

            -- Wait for signal assignment to take effect
            wait_spi_clk_cycles(1);

            -- Count how many chips are selected
            selected_chip_count := 0;
            for i in 0 to CHIP_COUNT - 1 loop
                if selected_chips(i) then
                    selected_chip_count := selected_chip_count + 1;
                end if;
            end loop;

            for i in 0 to selected_chip_count - 1 loop
                expected_tx_data := random.RandSlv(DATA_WIDTH);
                tx_fifo_write_data <= expected_tx_data;
                tx_fifo_write_enable <= '1';
                wait_spi_clk_cycles(1);
                tx_fifo_write_enable <= '0';
            end loop;

            wait_spi_clk_cycles(5);

            tx_trigger <= '1';
            wait_spi_clk_cycles(1);
            tx_trigger <= '0';

            wait until spi_busy;
            check_equal(got => spi_busy, expected => '1', msg => "TX should be active");

            -- Check each selected chip gets its transmission in the order they appear
            for i in 0 to CHIP_COUNT - 1 loop
                if selected_chips(i) then
                    active_chip_select_n_index := i;

                    -- Wait for this specific chip to be selected
                    expected_spi_chip_select_n := (others => '1');
                    expected_spi_chip_select_n(active_chip_select_n_index) := '0';

                    -- Wait until this chip is actually selected OR transmission ends
                    loop
                        wait_spi_clk_cycles(1);
                        exit when spi_chip_select_n = expected_spi_chip_select_n or spi_busy = '0';
                    end loop;

                    if spi_busy then
                        check_equal(got => spi_chip_select_n, expected => expected_spi_chip_select_n, msg => "spi_chip_select_n - Chip " & to_string(i) & " should be active");

                        -- Wait for the data transmission to complete for this chip
                        wait_tx_spi_clk_cycles(DATA_WIDTH);

                        -- Wait for chip to be deselected before checking next chip
                        loop
                            wait_spi_clk_cycles(1);
                            exit when spi_chip_select_n /= expected_spi_chip_select_n or spi_busy = '0';
                        end loop;
                        wait_spi_clk_cycles(1);
                    else
                        debug("Transmission ended before chip " & to_string(i) & " was selected");
                        exit; -- Exit the loop if transmission has ended
                    end if;
                end if;
            end loop;

            loopback_enabled <= false;
            wait_spi_clk_cycles(2);

            info("Multi-chip transfers test passed" & LF);
        end procedure;

        procedure test_multi_word_fifo_multi_chip_streaming is
            constant WORD_COUNT_PER_CHIP: positive := 5;

            variable expected_queue: queue_t;
            variable test_word: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            variable received_word: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            variable expected_word: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        begin
            info("Test 6.0) Multi-word FIFO streaming across multiple chips");

            reset_module;

            expected_queue := new_queue;

            spi_monitor_reset <= '1';
            selected_chips <= (0 => '1', 2 => '1', 4 => '1', others => '0');
            wait_spi_clk_cycles(1);
            spi_monitor_reset <= '0';

            for chip_idx in selected_chips'range loop
                if selected_chips(chip_idx) then
                    for word_idx in 0 to WORD_COUNT_PER_CHIP - 1 loop
                        test_word := random.RandSlv(Size => DATA_WIDTH);
                        push(queue => expected_queue, value => test_word);
                        tx_fifo_write_data <= test_word;
                        tx_fifo_write_enable <= '1';
                        wait_spi_clk_cycles(1);
                    end loop;
                end if;
            end loop;

            tx_fifo_write_enable <= '0';

            -- Wait for FIFO timing
            wait_spi_clk_cycles(5);

            tx_trigger <= '1';
            wait_spi_clk_cycles(1);
            tx_trigger <= '0';
            wait until and(spi_chip_select_n);

            while not is_empty(expected_queue) and not is_empty(received_queue) loop
                received_word := pop_std_ulogic_vector(queue => received_queue);
                expected_word := pop_std_ulogic_vector(queue => expected_queue);
                check_equal(got => received_word, expected => expected_word);
            end loop;

            wait until not spi_busy;
            wait_chip_select_n_cycles(2); -- Give some time after last chip deselection

            check_equal(got => spi_busy, expected => '0', msg => "TX should be inactive after transmission");
            check_equal(got => and(spi_chip_select_n), expected => '1', msg => "All chip selects should be deasserted");

            info("Multi-word multi-chip FIFO streaming test passed" & LF);
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
            elsif run("test_multi_word_fifo_multi_chip_streaming") then
                test_multi_word_fifo_multi_chip_streaming;
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
            SPI_CHIPS_AMOUNT => CHIP_COUNT,
            DATA_WIDTH => DATA_WIDTH,
            CONTROLLER_AND_NOT_PERIPHERAL => CONTROLLER_AND_NOT_PERIPHERAL,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB,
            ENABLE_INTERNAL_CLOCK_GATING => true,
            USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => false,
            TX_FIFO_DEPTH_IN_BITS => 4
        )
        port map (
            spi_clk_in => spi_clk_in,
            rst_n => rst_n,
            selected_chips => selected_chips,

            -- FIFO interface
            tx_fifo_write_clk => spi_clk_in,
            tx_fifo_write_enable => tx_fifo_write_enable,
            tx_fifo_write_data => tx_fifo_write_data,
            tx_fifo_write_blocked => tx_fifo_write_blocked,
            tx_fifo_full => tx_fifo_full,
            tx_fifo_empty => tx_fifo_empty,
            tx_fifo_words_stored => tx_fifo_words_stored,

            -- Streaming control
            tx_trigger => tx_trigger,
            spi_busy => spi_busy,

            rx_data => rx_data,
            rx_data_valid => rx_data_valid,
            spi_clk_out => spi_clk_out,
            serial_data_out => serial_data_out,
            serial_data_in => serial_data_in,
            spi_chip_select_n => spi_chip_select_n
        );
    ------------------------------------------------------------
end architecture;
