--!
--! @author:    N. Selvarajah
--! @brief:     API-style unit tests for the FIFO module.
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

entity tb_fifo_async is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_fifo_async is
    -------------------------------------------------------------
    -- Simulation parameters
    -------------------------------------------------------------
    constant ENABLE_DEBUG_PRINT: boolean := false;
    constant SIMULATION_TIMEOUT_TIME: time := 10 ms;
    constant DATA_WIDTH: positive := 8;
    constant FIFO_DEPTH: positive := 32;
    constant CDC_SYNC_STAGES: positive := 2;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- Clock and Reset
    -------------------------------------------------------------
    constant WRITE_CLK_FREQUENCY: real := real(50e6);
    constant READ_CLK_NORMAL_FREQUENCY: real := real(50e6);
    constant READ_CLK_SLOW_FREQUENCY: real := real(25e6);
    constant READ_CLK_FAST_FREQUENCY: real := real(100e6);

    constant PROPAGATION_TIME: time := 1 ns;

    signal fifo_aclr: std_ulogic := '0';
    signal write_clk: std_ulogic := '0';
    signal clk_read_normal: std_ulogic := '0';
    signal clk_read_slow: std_ulogic := '0';
    signal clk_read_fast: std_ulogic := '0';
    signal active_read_clk: std_ulogic;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DUT connections
    -------------------------------------------------------------
    signal fifo_write_enable: std_ulogic := '0';
    signal fifo_write_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal fifo_read_enable: std_ulogic := '0';
    signal fifo_read_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_read_data_valid: std_ulogic;
    signal fifo_empty: std_ulogic;
    signal fifo_full: std_ulogic;
    signal fifo_words_stored: natural;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- Testbench Internals
    -------------------------------------------------------------
    constant WORDS_TO_TEST: natural := 8;

    type clk_select_t is (normal, slow, fast);
    signal read_clk_select: clk_select_t := normal;

    signal write_clk_enable: std_ulogic := '1';
    signal clk_read_enable: std_ulogic := '1';

    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- Helper procedures
    -------------------------------------------------------------
    procedure wait_write_clock_cycles(cycles: natural) is
    begin
        for i in 0 to cycles - 1 loop
            wait until rising_edge(write_clk);
        end loop;
        wait for PROPAGATION_TIME;
    end procedure;

    procedure wait_read_clock_cycles(cycles: natural) is
    begin
        for i in 0 to cycles - 1 loop
            wait until rising_edge(active_read_clk);
        end loop;
        wait for PROPAGATION_TIME;
    end procedure;
    -------------------------------------------------------------
begin
    -------------------------------------------------------------
    -- CLOCK and RESET Generation
    -------------------------------------------------------------
    generate_advanced_clock(write_clk, WRITE_CLK_FREQUENCY, 0 fs, write_clk_enable);
    generate_advanced_clock(clk_read_normal, READ_CLK_NORMAL_FREQUENCY, 0 fs, clk_read_enable);
    generate_advanced_clock(clk_read_slow, READ_CLK_SLOW_FREQUENCY, 0 fs, clk_read_enable);
    generate_advanced_clock(clk_read_fast, READ_CLK_FAST_FREQUENCY, 0 fs, clk_read_enable);

    with read_clk_select select active_read_clk <=
        clk_read_normal when normal,
        clk_read_slow when slow,
        clk_read_fast when fast;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- VUnit
    -------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_fifo_async" & LF);

        if ENABLE_DEBUG_PRINT then
            show(display_handler, debug);
        end if;

        wait until simulation_done;
        info("Simulation done, all tests passed!" & LF);

        test_runner_cleanup(runner);
        wait;
    end process;
    -------------------------------------------------------------

     --------------------------------------------------
    -- Checker
    --------------------------------------------------
    checker: process
        variable random: RandomPType;
        variable write_count, read_count: natural;
        variable write_data, expected_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable test_data_queue: queue_t;

        procedure reset_fifo is begin
            if test_data_queue /= null_queue then
                flush(queue => test_data_queue);
            end if;
            test_data_queue := new_queue;

            fifo_aclr <= '1';
            fifo_write_enable <= '0';
            fifo_read_enable <= '0';
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);
            fifo_aclr <= '0';
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);
        end procedure;

        procedure test_basic_operations is begin
            info(
                "Test 1.0) test_basic_operations: " & LF &
                "Tests basic read/write operations across clock domains" & LF
            );

            read_clk_select <= normal;
            reset_fifo;
            write_count := 0;
            read_count := 0;

            -- Check initial conditions
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reset");
            check_equal(got => fifo_full, expected => '0', msg => "FIFO should not be full after reset");
            check_equal(got => fifo_words_stored, expected => 0, msg => "No words should be stored in FIFO after reset");

            -- Write some random data to the FIFO
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 100, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                write_count := write_count + 1;
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(2);
            end loop;

            -- Allow time for signals to propagate between clock domains
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);

            check_equal(got => fifo_empty, expected => '0', msg => "FIFO should not be empty after writes");

            -- Read back and verify data
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                debug("Read data: " & to_string(fifo_read_data) & ", Expected: " & to_string(expected_data));

                check_equal(got => fifo_read_data, expected => expected_data, msg => "Data mismatch at index " & to_string(i));
                read_count := read_count + 1;
                wait_read_clock_cycles(2);
            end loop;

            check_equal(got => write_count, expected => read_count, msg => "Read count doesn't match write count");
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after all reads");

            info("Test 1.0) Basic operations test completed successfully." & LF);
        end procedure;

        procedure test_full_flag is begin
            info(
                "Test 2.0) test_full_flag: " & LF &
                "Tests FIFO full flag behavior" & LF
            );

            read_clk_select <= normal;
            reset_fifo;

            -- Fill the FIFO completely
            for i in 0 to FIFO_DEPTH - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_ulogic_vector(to_unsigned(i + 200, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
            end loop;

            wait_write_clock_cycles(5);
            check_equal(got => fifo_full, expected => '1', msg => "FIFO should be full after filling completely");
            check_equal(got => fifo_words_stored, expected => FIFO_DEPTH, msg => "Words stored should be FIFO_DEPTH");

            -- Try writing when full
            wait_write_clock_cycles(1);
            fifo_write_enable <= '1';
            fifo_write_data <= std_ulogic_vector(to_unsigned(999, DATA_WIDTH));
            wait_write_clock_cycles(1);
            fifo_write_enable <= '0';

            -- Read one value to make space
            wait_read_clock_cycles(1);
            fifo_read_enable <= '1';
            wait_read_clock_cycles(1);
            fifo_read_enable <= '0';

            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);

            check_equal(got => fifo_full, expected => '0', msg => "FIFO should not be full after reading one word");

            -- Empty the FIFO
            for i in 1 to FIFO_DEPTH - 1 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';
                wait_read_clock_cycles(1);
                fifo_read_enable <= '0';
                wait_read_clock_cycles(1);
            end loop;

            wait_read_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reading all words");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be 0 after emptying");

            info("Test 2.0) Full flag test completed successfully." & LF);
        end procedure;

        procedure test_empty_flag is begin
            info(
                "Test 3.0) test_empty_flag: " & LF &
                "Tests FIFO empty flag behavior and edge cases" & LF
            );

            read_clk_select <= normal;
            reset_fifo;

            -- Verify initial empty state
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should start empty");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be zero when empty");

            -- Write and read a single word to test empty flag transitions
            wait_write_clock_cycles(1);
            fifo_write_enable <= '1';
            fifo_write_data <= std_logic_vector(to_unsigned(42, DATA_WIDTH));
            wait_write_clock_cycles(1);
            fifo_write_enable <= '0';

            wait_write_clock_cycles(5);  -- Allow synchronization
            wait_read_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '0', msg => "Empty flag should clear after write");

            wait_read_clock_cycles(1);
            fifo_read_enable <= '1';
            wait_read_clock_cycles(1);
            fifo_read_enable <= '0';

            wait_read_clock_cycles(5);  -- Allow synchronization
            check_equal(got => fifo_empty, expected => '1', msg => "Empty flag should assert after reading last word");

            -- Test read request when empty (should be ignored)
            wait_read_clock_cycles(1);
            fifo_read_enable <= '1';
            wait_read_clock_cycles(1);
            fifo_read_enable <= '0';

            wait_read_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should remain empty after read attempt on empty FIFO");

            info("Test 3.0) Empty flag test completed successfully." & LF);
        end procedure;

        procedure test_different_clock_speeds is begin
            info(
                "Test 4.0) test_different_clock_speeds: " & LF &
                "Tests FIFO operation with different read clock frequencies" & LF
            );

            read_clk_select <= slow;
            reset_fifo;

            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 300, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(2);
            end loop;

            info("Testing with random read clock speeds" & LF);

            -- Read data with fast read clock
            for i in 0 to WORDS_TO_TEST - 1 loop
                -- Randomly select a read clock speed
                read_clk_select <= clk_select_t'val(random.RandInt(
                    Min => clk_select_t'pos(clk_select_t'low),
                    Max => clk_select_t'pos(clk_select_t'high)
                ));

                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch with fast clock at index " & to_string(i)
                );
                wait_read_clock_cycles(2);
            end loop;

            info("Test 4.0) Different clock speeds test completed successfully." & LF);
        end procedure;

        procedure test_different_clock_domain_combinations is begin
            info(
                "Test 5.0) test_different_clock_domain_combinations: " & LF &
                "Tests FIFO with both fast write/slow read and slow write/fast read" & LF
            );

            info("Test 5.1) With fast write (100MHz) / slow read (50MHz)" & LF);
            read_clk_select <= slow;
            reset_fifo;

            -- Fill with test pattern
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 800, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(1);
            end loop;

            -- Verify data with slow reads
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch with fast write/slow read at index " & to_string(i)
                );
                wait_read_clock_cycles(2);
            end loop;

            info("Test 5.2) With slow write (simulated 50MHz) / fast read (200MHz)");
            read_clk_select <= fast;
            reset_fifo;

            -- Fill with test pattern using slower write timing
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 900, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';

                -- Add extra delay to simulate slower write clock
                wait for 20 ns;
            end loop;

            -- Wait for synchronization
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);

            -- Verify data with fast reads
            for i in 0 to WORDS_TO_TEST - 1 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch with slow write/fast read at index " & to_string(i)
                );
                wait_read_clock_cycles(1);  -- Shorter wait since we have fast reads
            end loop;

            info("Test 5.0) Different clock domain combinations test completed successfully." & LF);
        end procedure;

        procedure test_reset_behavior is begin
            info(
                "Test 6.0) test_reset_behavior: " & LF &
                "Tests FIFO reset behavior during operation" & LF
            );

            read_clk_select <= normal;
            reset_fifo;

            -- Write some data
            for i in 0 to 3 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_ulogic_vector(to_unsigned(i + 400, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(2);
            end loop;

            wait_write_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '0', msg => "FIFO should not be empty after writes");

            -- Reset during operation
            fifo_aclr <= '1';
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);
            fifo_aclr <= '0';
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);

            -- Verify state after reset
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reset");
            check_equal(got => fifo_full, expected => '0', msg => "FIFO should not be full after reset");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be 0 after reset");

            -- Verify normal operation after reset
            for i in 0 to 2 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 500, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(2);
            end loop;

            for i in 0 to 2 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch after reset at index " & to_string(i)
                );
                wait_read_clock_cycles(2);
            end loop;

            info("Test 6.0) Reset behavior test completed successfully." & LF);
        end procedure;

        procedure test_reset_during_operations is begin
            info(
                "Test 7.0) test_reset_during_operations: " & LF &
                "Tests reset at various operational points" & LF
            );

            info("Test 7.1) Reset during write operation" & LF);
            read_clk_select <= normal;
            reset_fifo;

            -- Start a write operation
            wait_write_clock_cycles(1);
            fifo_write_enable <= '1';
            fifo_write_data <= x"EF";

            -- Assert reset during write
            fifo_aclr <= '1';
            wait_write_clock_cycles(1);
            fifo_write_enable <= '0';
            wait_write_clock_cycles(3);
            fifo_aclr <= '0';
            wait_write_clock_cycles(5);

            -- Verify FIFO is empty and write was not completed
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reset during write");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be 0 after reset during write");

            info("Test 7.2) Reset during read operation" & LF);
            reset_fifo;

            -- Write some data
            for i in 0 to 3 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_logic_vector(to_unsigned(i + 1000, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(2);
            end loop;

            -- Start a read operation
            wait_read_clock_cycles(1);
            fifo_read_enable <= '1';

            -- Assert reset during read
            fifo_aclr <= '1';
            wait_read_clock_cycles(1);
            fifo_read_enable <= '0';
            wait_read_clock_cycles(3);
            fifo_aclr <= '0';
            wait_read_clock_cycles(5);

            -- Verify FIFO is empty and in correct state
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reset during read");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be 0 after reset during read");

            info("Test 7.3) Reset when almost full" & LF);
            reset_fifo;

            -- Fill FIFO to almost full
            for i in 0 to FIFO_DEPTH - 2 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_logic_vector(to_unsigned(i + 1100, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(1);
            end loop;

            -- Assert reset when almost full
            fifo_aclr <= '1';
            wait_write_clock_cycles(3);
            wait_read_clock_cycles(3);
            fifo_aclr <= '0';
            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);

            -- Verify FIFO is empty and in correct state
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after reset when almost full");
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should be 0 after reset when almost full");

            info("Test 7.0) Reset during operations test completed successfully." & LF);
        end procedure;

        procedure test_simultaneous_read_write is begin
            info(
                "Test 8.0) test_simultaneous_read_write: " & LF &
                "Tests FIFO operation with simultaneous reads and writes" & LF
            );

            read_clk_select <= normal;
            reset_fifo;

            -- First fill half the FIFO
            for i in 0 to (FIFO_DEPTH / 2) - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 600, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';
                wait_write_clock_cycles(1);
            end loop;

            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '0', msg => "FIFO should not be empty after writes");

            -- Now perform alternating simultaneous read/write operations
            for i in 0 to (FIFO_DEPTH / 2) - 1 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                write_data := std_ulogic_vector(to_unsigned(i + 700, DATA_WIDTH));
                fifo_write_data <= write_data;
                push(queue => test_data_queue, value => write_data);
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';
                fifo_write_enable <= '0';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                debug("Read data: " & to_string(fifo_read_data) & ", Expected: " & to_string(expected_data));
                debug("Words stored: " & to_string(fifo_words_stored));

                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch during simultaneous R/W at index " & to_string(i)
                );

                -- Check that words_stored remains constant during simultaneous operations
                check_equal(
                    got => fifo_words_stored = (FIFO_DEPTH / 2) or fifo_words_stored = (FIFO_DEPTH / 2) - 1,
                    expected => true,
                    msg => "Words stored should be around FIFO_DEPTH / 2 during simultaneous R/W"
                );

                wait_write_clock_cycles(2);
                wait_read_clock_cycles(2);
            end loop;

            -- Read out remaining words
            for i in 0 to (FIFO_DEPTH / 2) - 1 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';

                wait until fifo_read_data_valid;
                fifo_read_enable <= '0';
                expected_data := pop(queue => test_data_queue);
                check_equal(
                    got => fifo_read_data,
                    expected => expected_data,
                    msg => "Data mismatch when reading remaining words at index " & to_string(i)
                );
                wait_read_clock_cycles(2);
            end loop;

            wait_write_clock_cycles(5);
            wait_read_clock_cycles(5);
            check_equal(got => fifo_empty, expected => '1', msg => "FIFO should be empty after all reads");

            info("Test 8.0) Simultaneous read/write test completed successfully." & LF);
        end procedure;

        procedure test_word_count_accuracy is begin
            info(
                "Test 9.0) test_word_count_accuracy: " & LF &
                "Specifically tests fifo_words_stored accuracy under various conditions" & LF
            );

            reset_fifo;
            check_equal(got => fifo_words_stored, expected => 0, msg => "Words stored should start at zero");

            -- Add words one at a time and verify count
            for i in 1 to 8 loop
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_logic_vector(to_unsigned(i * 100, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';

                wait_write_clock_cycles(5);  -- Allow for synchronization
                wait_read_clock_cycles(5);

                check_equal(
                    got => fifo_words_stored,
                    expected => i,
                    msg => "Words stored should be " & to_string(i) & " after write #" & to_string(i)
                );
            end loop;

            -- Remove words one at a time and verify count
            for i in 7 downto 0 loop
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';
                wait_read_clock_cycles(1);
                fifo_read_enable <= '0';

                wait_read_clock_cycles(5);  -- Allow for synchronization

                check_equal(
                    got => fifo_words_stored,
                    expected => i,
                    msg => "Words stored should be " & to_string(i) & " after read"
                );
            end loop;

            -- Test rapid alternating writes and reads
            info("Test 9.1) Testing word count during alternating writes and reads");
            for i in 1 to 5 loop
                -- Write
                wait_write_clock_cycles(1);
                fifo_write_enable <= '1';
                fifo_write_data <= std_logic_vector(to_unsigned(i * 200, DATA_WIDTH));
                wait_write_clock_cycles(1);
                fifo_write_enable <= '0';

                wait_write_clock_cycles(3);
                wait_read_clock_cycles(3);

                -- Read
                wait_read_clock_cycles(1);
                fifo_read_enable <= '1';
                wait_read_clock_cycles(1);
                fifo_read_enable <= '0';
                wait_read_clock_cycles(3);

                -- Should remain at 0 after each read/write pair
                check_equal(
                    got => fifo_words_stored,
                    expected => 0,
                    msg => "Words stored should remain 0 after write/read pair #" & to_string(i)
                );
            end loop;

            info("Test 9.0) Word count accuracy test completed successfully." & LF);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        wait_write_clock_cycles(1);

        while test_suite loop
            if run("test_basic_operations") then
                test_basic_operations;
            elsif run("test_full_flag") then
                test_full_flag;
            elsif run("test_empty_flag") then
                test_empty_flag;
            elsif run("test_different_clock_speeds") then
                test_different_clock_speeds;
            elsif run("test_different_clock_domain_combinations") then
                test_different_clock_domain_combinations;
            elsif run("test_reset_behavior") then
                test_reset_behavior;
            elsif run("test_reset_during_operations") then
                test_reset_during_operations;
            elsif run("test_simultaneous_read_write") then
                test_simultaneous_read_write;
            elsif run("test_word_count_accuracy") then
                test_word_count_accuracy;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
        wait;
    end process;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- Instantiate module to test
    -------------------------------------------------------------
    DuT: entity work.fifo_async(own_behavioural_async_fifo)
        generic map (
            FIFO_DEPTH_IN_BITS => to_bits(FIFO_DEPTH),
            CDC_SYNC_STAGES => CDC_SYNC_STAGES
        )
        port map (
            aclr => fifo_aclr,
            write_clk => write_clk,
            read_clk => active_read_clk,
            write_enable => fifo_write_enable,
            write_data => fifo_write_data,
            read_enable => fifo_read_enable,
            read_data => fifo_read_data,
            read_data_valid => fifo_read_data_valid,
            full => fifo_full,
            empty => fifo_empty,
            words_stored => fifo_words_stored
        );
    -------------------------------------------------------------
end architecture;
