--!
--! @author:    N. Selvarajah
--! @brief:     Unit tests for the FIFO module.
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


entity tb_fifo_sync is
    generic (
        runner_cfg: string := runner_cfg_default;
        tb_path: string
    );
end entity;

architecture tb of tb_fifo_sync is
    -------------------------------------------------------------
    -- Internal tb signals/constants
    -------------------------------------------------------------
    constant PROPAGATION_TIME: time := 1 ns;
    constant SIMULATION_TIMEOUT_TIME: time := 1 ms;
    constant ENABLE_DEBUG_PRINT: boolean := false;

    constant SYS_CLK_FREQUENCY: real := real(100000000); -- 100 MHz
    constant SYS_CLK_PHASE: time := 0 fs;

    signal sys_clk_enable: std_ulogic := '1';
    signal simulation_done: boolean := false;
    -------------------------------------------------------------

    -------------------------------------------------------------
    -- DuT signals, constants
    -------------------------------------------------------------
    constant FIFO_DEPTH: positive := 1024;
    constant DATA_WIDTH: positive := 8;

    signal sys_clk: std_ulogic := '0';
    signal sys_rst_n: std_ulogic := '1';

    signal write_enable: std_ulogic := '0';
    signal read_enable: std_ulogic := '0';

    signal write_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal read_data_xilinx: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal read_data_own: std_ulogic_vector(DATA_WIDTH - 1 downto 0);

    signal full_xilinx: std_ulogic;
    signal full_own: std_ulogic;

    signal empty_xilinx: std_ulogic;
    signal empty_own: std_ulogic;

    signal words_stored_xilinx: natural range 0 to FIFO_DEPTH;
    signal words_stored_own: natural range 0 to FIFO_DEPTH;

    signal read_data_valid_xilinx: std_ulogic;
    signal read_data_valid_own: std_ulogic;
    -------------------------------------------------------------
begin
    ------------------------------------------------------------
    -- CLOCK and RESET Generation
    ------------------------------------------------------------
    sys_clk_enable <= '1';
    generate_advanced_clock(sys_clk, SYS_CLK_FREQUENCY, SYS_CLK_PHASE, sys_clk_enable);
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- VUnit
    ------------------------------------------------------------
    test_runner_watchdog(runner, SIMULATION_TIMEOUT_TIME);

    main: process begin
        test_runner_setup(runner, runner_cfg);
        info("Starting tb_fifo_sync");

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

        procedure check_fifo_status(expected_full, expected_empty: std_ulogic := '-') is begin
            if expected_full /= '-' then
                -- check_equal(got => full_xilinx, expected => expected_full, msg => "full_xilinx");
                check_equal(got => full_own, expected => expected_full, msg => "full_own");
            end if;
            if expected_empty /= '-' then
                -- check_equal(got => empty_xilinx, expected => expected_empty, msg => "empty_xilinx");
                check_equal(got => empty_own, expected => expected_empty, msg => "empty_own");
            end if;
        end procedure;

        procedure check_fifo_output(expected_data: std_ulogic_vector) is begin
            -- check_equal(got => read_data_xilinx, expected => expected_data, msg => "read_data_xilinx");
            check_equal(got => read_data_own, expected => expected_data, msg => "read_data_own");
        end procedure;

        procedure check_word_count(expected_count: natural) is begin
            check_equal(got => words_stored_own, expected => expected_count, msg => "words_stored_own");
        end procedure;

        procedure test_empty_fifo is begin
            info("Test 1.0) test_empty_fifo" & LF);
            restart_module;
            check_fifo_status(expected_full => '0', expected_empty => '1');

            write_enable <= '0';
            read_enable <= '1';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '1');

            write_enable <= '1';
            read_enable <= '0';
            write_data <= random.RandSlv(write_data'length);
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '0');

            write_enable <= '0';
            read_enable <= '1';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '1');
            check_fifo_output(expected_data => write_data);

            wait_sys_clk_cycles(random.RandInt(1, 10));
            check_fifo_status(expected_full => '0', expected_empty => '1');
            read_enable <= '0';
            write_enable <= '0';

            wait_sys_clk_cycles(1);
            info("Test 1.0) test_empty_fifo completed successfully" & LF);
        end procedure;

        procedure test_full_fifo is begin
            info("Test 2.0) test_full_fifo" & LF);
            restart_module;

            check_fifo_status(expected_full => '0', expected_empty => '1');

            for i in 0 to FIFO_DEPTH - 1 loop
                write_enable <= '1';
                read_enable <= '0';
                write_data <= std_ulogic_vector(to_unsigned(i mod 2**write_data'length, write_data'length));
                wait_sys_clk_cycles(1);

                if i = FIFO_DEPTH - 1 then
                    check_fifo_status(expected_full => '1', expected_empty => '0');
                else
                    check_fifo_status(expected_full => '0', expected_empty => '0');
                end if;
            end loop;

            for i in 0 to FIFO_DEPTH - 1 loop
                write_enable <= '0';
                read_enable <= '1';
                wait_sys_clk_cycles(1);
                -- FIFO reads in FIFO order (first-in, first-out), so we expect the data in write order
                check_fifo_output(expected_data => std_ulogic_vector(to_unsigned(i mod 2**write_data'length, write_data'length)));

                if i = FIFO_DEPTH - 1 then
                    check_fifo_status(expected_full => '0', expected_empty => '1');
                else
                    check_fifo_status(expected_full => '0', expected_empty => '0');
                end if;
            end loop;

            write_enable <= '0';
            read_enable <= '0';
            wait_sys_clk_cycles(1);
            info("Test 2.0) test_full_fifo completed successfully" & LF);
        end procedure;

        procedure test_when_write_and_read_requests_are_active is
            variable past_data: write_data'subtype;
            variable new_data: write_data'subtype;
        begin
            info("Test 3.0) test_when_write_and_read_requests_are_active" & LF);
            restart_module;

            check_fifo_status(expected_full => '0', expected_empty => '1');

            -- Step 1: Write first item
            write_enable <= '1';
            read_enable <= '0';
            write_data <= random.RandSlv(write_data'length);
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '0');
            past_data := write_data;

            -- Step 2: Simultaneous write and read
            write_enable <= '1';
            read_enable <= '1';
            new_data := random.RandSlv(write_data'length);
            write_data <= new_data;
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '0');
            check_fifo_output(expected_data => past_data);  -- Should read the first item

            -- Step 3: Stop both operations
            write_enable <= '0';
            read_enable <= '0';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '0');
            -- Note: not checking read_data here since no read is active

            -- Step 4: Read the second item that was written in step 2
            read_enable <= '1';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '1');  -- Should be empty now
            check_fifo_output(expected_data => new_data);

            read_enable <= '0';
            wait_sys_clk_cycles(1);
            info("Test 3.0) test_when_write_and_read_requests_are_active completed successfully" & LF);
        end procedure;

        procedure test_reset_behavior is begin
            info("Test 4.0) test_reset_behavior" & LF);
            restart_module;

            -- Write some data
            for i in 0 to 7 loop
                write_enable <= '1';
                read_enable <= '0';
                write_data <= std_ulogic_vector(to_unsigned(i + 100, write_data'length));
                wait_sys_clk_cycles(1);
            end loop;
            write_enable <= '0';

            wait_sys_clk_cycles(2);
            check_fifo_status(expected_full => '0', expected_empty => '0');

            -- Reset during operation
            sys_rst_n <= '0';
            wait_sys_clk_cycles(3);
            sys_rst_n <= '1';
            wait_sys_clk_cycles(2);

            -- Verify state after reset
            check_fifo_status(expected_full => '0', expected_empty => '1');
            check_word_count(expected_count => 0);

            -- Verify normal operation after reset
            write_enable <= '1';
            write_data <= std_ulogic_vector(to_unsigned(42, write_data'length));
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '0');

            write_enable <= '0';
            read_enable <= '1';
            wait_sys_clk_cycles(1);
            check_fifo_output(expected_data => std_ulogic_vector(to_unsigned(42, write_data'length)));
            check_fifo_status(expected_full => '0', expected_empty => '1');

            read_enable <= '0';
            wait_sys_clk_cycles(1);
            info("Test 4.0) test_reset_behavior completed successfully" & LF);
        end procedure;

        procedure test_reset_during_operations is begin
            info("Test 5.0) test_reset_during_operations" & LF);

            info("Test 5.1) Reset during write operation" & LF);
            restart_module;

            -- Start a write operation
            write_enable <= '1';
            write_data <= x"EF";
            wait_sys_clk_cycles(1);

            -- Assert reset during write
            sys_rst_n <= '0';
            wait_sys_clk_cycles(1);
            write_enable <= '0';
            wait_sys_clk_cycles(2);
            sys_rst_n <= '1';
            wait_sys_clk_cycles(2);

            -- Verify FIFO is empty and write was not completed
            check_fifo_status(expected_full => '0', expected_empty => '1');

            info("Test 5.2) Reset during read operation" & LF);
            restart_module;

            -- Write some data first
            write_enable <= '1';
            write_data <= x"AA";
            wait_sys_clk_cycles(1);
            write_data <= x"BB";
            wait_sys_clk_cycles(1);
            write_enable <= '0';

            -- Start a read operation
            read_enable <= '1';
            wait_sys_clk_cycles(1);

            -- Assert reset during read
            sys_rst_n <= '0';
            wait_sys_clk_cycles(1);
            read_enable <= '0';
            wait_sys_clk_cycles(2);
            sys_rst_n <= '1';
            wait_sys_clk_cycles(2);

            -- Verify FIFO is empty and in correct state
            check_fifo_status(expected_full => '0', expected_empty => '1');

            info("Test 5.0) test_reset_during_operations completed successfully" & LF);
        end procedure;

        procedure test_word_count_accuracy is begin
            info("Test 6.0) test_word_count_accuracy" & LF);
            restart_module;

            -- Test word count with incremental writes
            for i in 0 to 15 loop
                write_enable <= '1';
                write_data <= std_ulogic_vector(to_unsigned(i, write_data'length));
                wait_sys_clk_cycles(1);
                write_enable <= '0';
                wait_sys_clk_cycles(1);

                -- Check that word count is correct
                check_equal(got => words_stored_own, expected => i + 1, msg => "Words stored count after " & to_string(i+1) & " writes");
            end loop;

            -- Test word count with incremental reads
            for i in 15 downto 0 loop
                read_enable <= '1';
                wait_sys_clk_cycles(1);
                read_enable <= '0';
                wait_sys_clk_cycles(1);

                -- Check word count
                check_equal(got => words_stored_own, expected => i, msg => "Words stored count after reading, " & to_string(i) & " remaining");

                if i = 0 then
                    check_fifo_status(expected_full => '0', expected_empty => '1');
                else
                    check_fifo_status(expected_full => '0', expected_empty => '0');
                end if;
            end loop;

            info("Test 6.0) test_word_count_accuracy completed successfully" & LF);
        end procedure;

        procedure test_simultaneous_read_write_advanced is begin
            info("Test 7.0) test_simultaneous_read_write_advanced" & LF);
            restart_module;

            -- First fill half the FIFO
            for i in 0 to 15 loop
                write_enable <= '1';
                write_data <= std_ulogic_vector(to_unsigned(i + 200, write_data'length));
                wait_sys_clk_cycles(1);
            end loop;
            write_enable <= '0';
            wait_sys_clk_cycles(2);

            -- Now perform simultaneous read/write operations
            for i in 0 to 7 loop
                write_enable <= '1';
                read_enable <= '1';
                write_data <= std_ulogic_vector(to_unsigned(i + 300, write_data'length));
                wait_sys_clk_cycles(1);

                -- Check that read data matches expected (FIFO order)
                check_fifo_output(expected_data => std_ulogic_vector(to_unsigned(i + 200, write_data'length)));
            end loop;

            write_enable <= '0';
            read_enable <= '0';
            wait_sys_clk_cycles(2);

            -- Read remaining data
            for i in 8 to 15 loop
                read_enable <= '1';
                wait_sys_clk_cycles(1);
                check_fifo_output(expected_data => std_ulogic_vector(to_unsigned(i + 200, write_data'length)));
            end loop;

            -- Read the new data that was written during simultaneous operation
            for i in 0 to 7 loop
                wait_sys_clk_cycles(1);
                check_fifo_output(expected_data => std_ulogic_vector(to_unsigned(i + 300, write_data'length)));
            end loop;

            read_enable <= '0';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '1');

            info("Test 7.0) test_simultaneous_read_write_advanced completed successfully" & LF);
        end procedure;

        procedure test_edge_cases is begin
            info("Test 8.0) test_edge_cases" & LF);
            restart_module;

            info("Test 8.1) Write when full (should be ignored)" & LF);
            -- Fill FIFO completely
            for i in 0 to FIFO_DEPTH - 1 loop
                write_enable <= '1';
                write_data <= std_ulogic_vector(to_unsigned(i mod 256, write_data'length));
                wait_sys_clk_cycles(1);
            end loop;
            write_enable <= '0';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '1', expected_empty => '0');

            -- Try to write when full (should be ignored)
            write_enable <= '1';
            write_data <= x"FF";
            wait_sys_clk_cycles(3);
            write_enable <= '0';
            check_fifo_status(expected_full => '1', expected_empty => '0');

            info("Test 8.2) Read when empty (should be ignored)" & LF);
            -- Empty the FIFO
            for i in 0 to FIFO_DEPTH - 1 loop
                read_enable <= '1';
                wait_sys_clk_cycles(1);
            end loop;
            read_enable <= '0';
            wait_sys_clk_cycles(1);
            check_fifo_status(expected_full => '0', expected_empty => '1');

            -- Try to read when empty (should be ignored)
            read_enable <= '1';
            wait_sys_clk_cycles(3);
            read_enable <= '0';
            check_fifo_status(expected_full => '0', expected_empty => '1');

            info("Test 8.0) test_edge_cases completed successfully" & LF);
        end procedure;

        procedure test_stress_operations is
            variable num_writes: natural;
        begin
            info("Test 9.0) test_stress_operations" & LF);
            restart_module;

            -- Stress test with rapid write/read cycles
            info("Test 9.1) Rapid write/read cycles" & LF);
            for cycle in 0 to 9 loop
                -- Rapid writes
                for i in 0 to 31 loop
                    write_enable <= '1';
                    write_data <= std_ulogic_vector(to_unsigned((cycle * 32 + i) mod 256, write_data'length));
                    wait_sys_clk_cycles(1);
                end loop;
                write_enable <= '0';

                -- Rapid reads
                for i in 0 to 31 loop
                    read_enable <= '1';
                    wait_sys_clk_cycles(1);
                    check_fifo_output(expected_data => std_ulogic_vector(to_unsigned((cycle * 32 + i) mod 256, write_data'length)));
                end loop;
                read_enable <= '0';
                wait_sys_clk_cycles(1);

                check_fifo_status(expected_full => '0', expected_empty => '1');
            end loop;

            info("Test 9.2) Random write/read patterns" & LF);
            for cycle in 0 to 4 loop
                -- Random number of writes (1-10)
                num_writes := random.RandInt(1, 10);

                for i in 0 to num_writes - 1 loop
                    write_enable <= '1';
                    write_data <= random.RandSlv(write_data'length);
                    wait_sys_clk_cycles(1);
                end loop;
                write_enable <= '0';

                -- Random delay
                wait_sys_clk_cycles(random.RandInt(1, 3));

                -- Read same number of items
                for i in 0 to num_writes - 1 loop
                    read_enable <= '1';
                    wait_sys_clk_cycles(1);
                end loop;
                read_enable <= '0';

                wait_sys_clk_cycles(1);
            end loop;

            check_fifo_status(expected_full => '0', expected_empty => '1');
            info("Test 9.0) test_stress_operations completed successfully" & LF);
        end procedure;
    begin
        random.InitSeed(tb_path & random'instance_name);

        -- Don't remove, else VUnit will not run the test suite
        wait_sys_clk_cycles(1);

        while test_suite loop
            if run("test_empty_fifo") then
                test_empty_fifo;
            elsif run("test_full_fifo") then
                test_full_fifo;
            elsif run("test_when_write_and_read_requests_are_active") then
                test_when_write_and_read_requests_are_active;
            elsif run("test_reset_behavior") then
                test_reset_behavior;
            elsif run("test_reset_during_operations") then
                test_reset_during_operations;
            elsif run("test_word_count_accuracy") then
                test_word_count_accuracy;
            elsif run("test_simultaneous_read_write_advanced") then
                test_simultaneous_read_write_advanced;
            elsif run("test_edge_cases") then
                test_edge_cases;
            elsif run("test_stress_operations") then
                test_stress_operations;
            else
                assert false report "No test has been run!" severity failure;
            end if;
        end loop;

        simulation_done <= true;
    end process;
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- Instantiate the DuT
    ------------------------------------------------------------
    DuT_xilinx: entity work.fifo_sync(xilinx_behavioural_sync_fifo)
        generic map (
            FIFO_DEPTH => FIFO_DEPTH
        )
        port map (
            sys_clk => sys_clk,
            sys_rst_n => sys_rst_n,
            write_enable => write_enable,
            write_data => write_data,
            read_enable => read_enable,
            read_data => read_data_xilinx,
            read_data_valid => read_data_valid_xilinx,
            full => full_xilinx,
            empty => empty_xilinx,
            words_stored => words_stored_xilinx
        );

    DuT_own: entity work.fifo_sync(own_behavioural_sync_fifo)
        generic map (
            FIFO_DEPTH => FIFO_DEPTH
        )
        port map (
            sys_clk => sys_clk,
            sys_rst_n => sys_rst_n,
            write_enable => write_enable,
            write_data => write_data,
            read_enable => read_enable,
            read_data => read_data_own,
            read_data_valid => read_data_valid_own,
            full => full_own,
            empty => empty_own,
            words_stored => words_stored_own
        );
    ------------------------------------------------------------
end architecture;
