--!
--! @author:    N. Selvarajah
--! @brief:     This module is a wrapper for the async FIFO of Xilinx technology.
--! @details:   Based on Simulation and Synthesis Techniques for Asynchronous FIFO Design by Clifford E. Cummings, Sunburst Design, Inc.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;
use work.memories_pkg.all;

entity fifo_async is
    generic (
        FIFO_DEPTH_IN_BITS: natural range 0 to to_bits(natural'high) := 2;
        CDC_SYNC_STAGES: positive := 2;
        INTEL_DEVICE_FAMILY: string := "Cyclone V"; -- Change this to your target Intel device family
        INTEL_CLOCKS_ARE_SYNCHRONIZED: boolean := false
    );
    port (
        aclr: in std_ulogic;
        write_clk: in std_ulogic;
        read_clk: in std_ulogic;
        write_enable: in std_ulogic;
        write_data: in std_ulogic_vector;
        read_enable: in std_ulogic;
        read_data: out std_ulogic_vector;
        read_data_valid: out std_ulogic;
        full: out std_ulogic;
        empty: out std_ulogic;
        words_stored: out natural range 0 to 2**FIFO_DEPTH_IN_BITS
    );

    constant FIFO_DEPTH: natural := 2**FIFO_DEPTH_IN_BITS;
    constant ADDRESS_WIDTH: natural := to_bits(FIFO_DEPTH);
end entity;

library xpm;
use xpm.vcomponents.all;

--!
--! @brief: This module is a Xilinx technology specific FIFO memory block.
--! @note:  This module is a wrapper for the xpm_fifo_async module.
--! @note:  Use this primarily for Xilinx technology.
--!
architecture xilinx_behavioural_async_fifo of fifo_async is
    signal prog_full_unconnected: std_ulogic;
    signal prog_empty_unconnected: std_ulogic;
    signal wr_data_count: std_ulogic_vector(ADDRESS_WIDTH downto 0);
    signal rd_data_count_unconnected: std_ulogic_vector(0 downto 0);
    signal wr_ack_unconnected: std_ulogic;
    signal overflow_unconnected: std_ulogic;
    signal underflow_unconnected: std_ulogic;
    signal wr_rst_busy_unconnected: std_ulogic;
    signal rd_rst_busy_unconnected: std_ulogic;
    signal almost_full_unconnected: std_ulogic;
    signal almost_empty_unconnected: std_ulogic;
    signal sbiterr_unconnected: std_ulogic;
    signal dbiterr_unconnected: std_ulogic;
begin
    words_stored <= to_integer(unsigned(wr_data_count));
    xpm_fifo_inst: xpm_fifo_async
        generic map (
            FIFO_MEMORY_TYPE => "auto",
            FIFO_WRITE_DEPTH => FIFO_DEPTH,
            CDC_SYNC_STAGES => CDC_SYNC_STAGES,
            CASCADE_HEIGHT => 0,
            WRITE_DATA_WIDTH => write_data'length,
            READ_MODE => "std",
            FIFO_READ_LATENCY => 1,
            FULL_RESET_VALUE => 0,
            USE_ADV_FEATURES => "0707",
            READ_DATA_WIDTH => read_data'length,
            WR_DATA_COUNT_WIDTH => wr_data_count'length,
            PROG_FULL_THRESH => 10,
            RD_DATA_COUNT_WIDTH => rd_data_count_unconnected'length,
            PROG_EMPTY_THRESH => 10,
            DOUT_RESET_VALUE => "0",
            ECC_MODE => "no_ecc",
            SIM_ASSERT_CHK => 0,
            RELATED_CLOCKS => 0,
            WAKEUP_TIME => 0
        )
        port map (
            sleep => '0',
            rst => aclr,
            wr_clk => write_clk,
            wr_en => write_enable,
            din => write_data,
            full => full,
            prog_full => prog_full_unconnected,
            wr_data_count => wr_data_count,
            overflow => overflow_unconnected,
            wr_rst_busy => wr_rst_busy_unconnected,
            almost_full => almost_full_unconnected,
            wr_ack => wr_ack_unconnected,
            rd_en => read_enable,
            rd_clk => read_clk,
            dout => read_data,
            empty => empty,
            prog_empty => prog_empty_unconnected,
            rd_data_count => rd_data_count_unconnected,
            underflow => underflow_unconnected,
            rd_rst_busy => rd_rst_busy_unconnected,
            almost_empty => almost_empty_unconnected,
            data_valid => read_data_valid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr => sbiterr_unconnected,
            dbiterr => dbiterr_unconnected
        );
end architecture;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture intel_behavioural_async_fifo of fifo_async is
    function boolean_to_string(b: boolean) return string is begin
        if b then
            return "TRUE";
        else
            return "FALSE";
        end if;
    end function;

    signal words_stored_slv: std_ulogic_vector(ADDRESS_WIDTH downto 0);
begin
    -- NOTE: -- enable_ecc and write_aclr_synch are not supported in the Intel Cyclone V device family.
    fifo: dcfifo
        generic map (
            add_ram_output_register => "OFF",
            intended_device_family => INTEL_DEVICE_FAMILY,
            lpm_type => "dcfifo",
            lpm_hint => "DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE",
            lpm_showahead => "OFF",
            use_eab => "ON", -- ON = RAM, OFF Register
            -- enable_ecc => "FALSE",
            ram_block_type => "AUTO",
            overflow_checking => "ON",
            underflow_checking => "ON",

            clocks_are_synchronized => boolean_to_string(INTEL_CLOCKS_ARE_SYNCHRONIZED),
            wrsync_delaypipe => 0, -- The values of this parameter is internally reduced by two.
            rdsync_delaypipe => 0, -- The values of this parameter is internally reduced by two.
            delay_rdusedw => 1,
            delay_wrusedw => 1,
            write_aclr_synch => "OFF",
            -- read_aclr_synch => "OFF",

            lpm_numwords => FIFO_DEPTH,
            lpm_widthu => to_bits(FIFO_DEPTH),
            lpm_width => write_data'length,
            add_usedw_msb_bit => "OFF"
        )
        port map (
            aclr => aclr,

            wrclk => write_clk,
            data => write_data,
            wrreq => write_enable,
            wrempty => open,
            wrfull => full,
            wrusedw => words_stored_slv,

            rdclk => read_clk,
            q => read_data,
            rdreq => read_enable,
            rdempty => empty,
            rdfull => open,
            rdusedw => open -- May not be available
        );

        read_data_valid <= read_enable when rising_edge(read_clk);
        words_stored <= to_integer(unsigned(words_stored_slv)) when not full else words_stored'subtype'high;
end architecture;

--!
--! @brief: This module is a generic FIFO memory block.
--! @note:  This module is technology independent and can be replaced with a technology specific async FIFO module.
--! @note:  Use this if you don't have a technology specific async FIFO.
--!
architecture own_behavioural_async_fifo of fifo_async is
    subtype pointer_t is unsigned(ADDRESS_WIDTH downto 0);

    signal write_pointer_binary: pointer_t;
    signal read_pointer_binary: pointer_t;

    signal write_pointer_gray: std_ulogic_vector(pointer_t'range);
    signal read_pointer_gray: std_ulogic_vector(pointer_t'range);

    signal write_pointer_gray_sync: std_ulogic_vector(pointer_t'range);
    signal read_pointer_gray_sync: std_ulogic_vector(pointer_t'range);

    signal write_address: unsigned(ADDRESS_WIDTH - 1 downto 0);
    signal read_address: unsigned(ADDRESS_WIDTH - 1 downto 0);

    function binary_to_gray(binary: unsigned) return std_ulogic_vector is begin
        return std_ulogic_vector(binary xor ('0' & binary(binary'high downto 1)));
    end function;

    function gray_to_binary(gray: std_ulogic_vector) return unsigned is
        variable binary: unsigned(gray'range);
    begin
        binary(gray'high) := gray(gray'high);
        for i in gray'high - 1 downto 0 loop
            binary(i) := binary(i + 1) xor gray(i);
        end loop;
        return binary;
    end function;
begin
    words_stored_calc: process (read_clk)
        variable write_ptr_sync: unsigned(ADDRESS_WIDTH downto 0);
        variable diff: integer;
    begin
        if rising_edge(read_clk) then
            write_ptr_sync := gray_to_binary(write_pointer_gray_sync);
            diff := to_integer(write_ptr_sync) - to_integer(read_pointer_binary);
            words_stored <= words_stored'subtype'high when full else diff;
        end if;
    end process;

    write_pointer_logic: process (aclr, write_clk)
    begin
        if aclr then
            write_pointer_binary <= (others => '0');
            write_pointer_gray <= (others => '0');
        elsif rising_edge(write_clk) then
            if write_enable and not full then
                write_pointer_binary <= write_pointer_binary + 1;
                write_pointer_gray <= binary_to_gray(write_pointer_binary + 1);
            end if;
        end if;
    end process;

    read_pointer_logic: process (aclr, read_clk)
    begin
        if aclr then
            read_pointer_binary <= (others => '0');
            read_pointer_gray <= (others => '0');
        elsif rising_edge(read_clk) then
            if read_enable and not empty then
                read_pointer_binary <= read_pointer_binary + 1;
                read_pointer_gray <= binary_to_gray(read_pointer_binary + 1);
            end if;
        end if;
    end process;

    write_pointer_sync: entity work.ff_synchroniser_vector(xilinx_behavioural_ff_synchroniser_vector)
        generic map (
            DEST_SYNC_FF => CDC_SYNC_STAGES
        )
        port map (
            source_clk => write_clk,
            destination_clk => read_clk,
            in_data => write_pointer_gray,
            in_data_valid => '1',
            out_data => write_pointer_gray_sync,
            out_data_valid => open
        );

    read_pointer_sync: entity work.ff_synchroniser_vector(xilinx_behavioural_ff_synchroniser_vector)
        generic map (
            DEST_SYNC_FF => CDC_SYNC_STAGES
        )
        port map (
            source_clk => read_clk,
            destination_clk => write_clk,
            in_data => read_pointer_gray,
            in_data_valid => '1',
            out_data => read_pointer_gray_sync,
            out_data_valid => open
        );

    empty <= '1' when read_pointer_gray = write_pointer_gray_sync else '0';

    full_flag_detect: process (all)
        variable pointers_msbs_are_different: boolean;
        variable addresses_msbs_are_different: boolean;
        variable lower_address_parts_are_equal: boolean;
    begin
        pointers_msbs_are_different := write_pointer_gray(write_pointer_gray'high) /= read_pointer_gray_sync(read_pointer_gray_sync'high);
        addresses_msbs_are_different := write_pointer_gray(write_pointer_gray'high - 1) /= read_pointer_gray_sync(read_pointer_gray_sync'high - 1);
        lower_address_parts_are_equal := write_pointer_gray(write_pointer_gray'high - 2 downto 0) = read_pointer_gray_sync(read_pointer_gray_sync'high - 2 downto 0);
        full <= '1' when pointers_msbs_are_different and addresses_msbs_are_different and lower_address_parts_are_equal else '0';
    end process;

    write_address <= write_pointer_binary(write_address'range);
    read_address <= read_pointer_binary(read_address'range);

    valid_flag_detect: process (aclr, read_clk)
    begin
        if aclr then
            read_data_valid <= '0';
        elsif rising_edge(read_clk) then
            read_data_valid <= read_enable and not empty;
        end if;
    end process;

    dual_port_ram_inst: entity work.dual_clock_dual_port_ram
        port map (
            write_clk => write_clk,
            write_enable => write_enable and not full,
            write_data => write_data,
            write_address => std_ulogic_vector(write_address),
            read_clk => read_clk,
            read_data => read_data,
            read_address => std_ulogic_vector(read_address)
        );
end architecture;
