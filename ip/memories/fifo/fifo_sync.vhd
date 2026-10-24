library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;

entity fifo_sync is
    generic (
        FIFO_DEPTH: positive := 2;
        UNDER_AND_OVERFLOW_ASSERTIONS: boolean := false;
        INTEL_DEVICE_FAMILY: string := "Cyclone V"  -- Change this to your target Intel device family
    );
    port (
        sys_clk: in std_ulogic;
        sys_rst_n: in std_ulogic;
        write_enable: in std_ulogic;
        write_data: in std_ulogic_vector;
        read_enable: in std_ulogic;
        read_data: out std_ulogic_vector;
        read_data_valid: out std_ulogic;
        full: out std_ulogic;
        empty: out std_ulogic;
        words_stored: out natural range 0 to FIFO_DEPTH
    );
end entity;

library xpm;
use xpm.vcomponents.all;

use work.fifo_pkg.all;

--!
--! @brief: This module is a Xilinx technology specific FIFO memory block.
--! @note:  This module is a wrapper for the xpm_fifo_sync module.
--! @note:  Use this primarily for Xilinx technology.
--! @note:  XPM's wr_data_count is a registered status value that trails the
--!         write pointer by a cycle, and its full flag does not count the two
--!         fall-through stage words (depth 16 admits 18 words), so neither
--!         signal can gate writes to an exact FIFO_DEPTH. The fill level is
--!         therefore tracked locally in fill_level.
--! @note:  The consumer should respect full and empty. Reads while empty
--!         are ignored, exactly as XPM does internally; writes beyond full
--!         are dropped at the XPM input so fill_level stays in lockstep
--!         (XPM's own full flag fires two words later in fall-through mode).
--!
architecture xilinx_behavioural_sync_fifo of fifo_sync is
    signal fill_level: natural range 0 to FIFO_DEPTH;
    signal write_accepted: std_ulogic;
    signal read_accepted: std_ulogic;
    signal wr_data_count_unconnected: std_ulogic_vector(to_bits(FIFO_DEPTH) downto 0);

    -- xpm_fifo_sync signals
    -- Define slv vector for xpm_fifo_sync
    signal prog_full_unconnected: std_ulogic;
    signal prog_empty_unconnected: std_ulogic;
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
    -- full asserts at exactly FIFO_DEPTH stored words, as with the other
    -- architectures.
    full <= '1' when fill_level >= FIFO_DEPTH else '0';
    words_stored <= fill_level;

    -- Exactly what reaches the XPM input, so fill_level mirrors the XPM: a
    -- write only while not full (XPM's own full flag fires two words later
    -- in fall-through mode), a read only while not empty (the XPM ignores
    -- that violation itself).
    write_accepted <= write_enable and not full;
    read_accepted <= read_enable and not empty;

    fill_level_proc: process (sys_clk) is begin
        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                fill_level <= 0;
            elsif write_accepted and not read_accepted then
                fill_level <= fill_level + 1;
            elsif not write_accepted and read_accepted then
                fill_level <= fill_level - 1;
            end if;
        end if;
    end process;

    -- In fall-through mode the data is already valid before the read, so a
    -- plain read-enable pass-through is enough; whether a word is available
    -- is the consumer's empty check, done outside.
    read_data_valid <= read_enable;

    xpm_fifo_inst: xpm_fifo_sync
        generic map (
            FIFO_MEMORY_TYPE => "auto",
            FIFO_WRITE_DEPTH => FIFO_DEPTH,
            CASCADE_HEIGHT => 0,
            WRITE_DATA_WIDTH => write_data'length,
            -- Fall through: the head word is available on dout before rd_en
            READ_MODE => "fwft",
            FIFO_READ_LATENCY => 1,
            FULL_RESET_VALUE => 0,
            -- Overflow diagnostics (the word count is tracked locally)
            USE_ADV_FEATURES => use_advanced_features(enable_overflow => true),
            READ_DATA_WIDTH => read_data'length,
            WR_DATA_COUNT_WIDTH => wr_data_count_unconnected'length,
            PROG_FULL_THRESH => 5,
            RD_DATA_COUNT_WIDTH => rd_data_count_unconnected'length,
            PROG_EMPTY_THRESH => 3,
            DOUT_RESET_VALUE => "0",
            ECC_MODE => "no_ecc",
            SIM_ASSERT_CHK => 0,
            WAKEUP_TIME => 0
        )
        port map (
            sleep => '0',
            rst => not sys_rst_n,
            wr_clk => sys_clk,
            wr_en => write_accepted,
            din => write_data,
            full => open,
            prog_full => prog_full_unconnected,
            wr_data_count => wr_data_count_unconnected,
            overflow => overflow_unconnected,
            wr_rst_busy => wr_rst_busy_unconnected,
            almost_full => almost_full_unconnected,
            wr_ack => wr_ack_unconnected,
            rd_en => read_enable,
            dout => read_data,
            empty => empty,
            prog_empty => prog_empty_unconnected,
            rd_data_count => rd_data_count_unconnected,
            underflow => underflow_unconnected,
            rd_rst_busy => rd_rst_busy_unconnected,
            almost_empty => almost_empty_unconnected,
            data_valid => open,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr => sbiterr_unconnected,
            dbiterr => dbiterr_unconnected
        );
end architecture;

library altera_mf;
use altera_mf.altera_mf_components.all;

architecture intel_behavioural_sync_fifo of fifo_sync is
    signal words_stored_slv: std_ulogic_vector(to_bits(FIFO_DEPTH) - 1 downto 0);
begin
    fifo_inst: scfifo
        generic map (
            add_ram_output_register => "ON",
            intended_device_family => INTEL_DEVICE_FAMILY,

            lpm_showahead => "OFF",
            lpm_type => "scfifo",
            lpm_numwords => FIFO_DEPTH,
            lpm_width => write_data'length,
            lpm_widthu => to_bits(FIFO_DEPTH),

            use_eab => "ON", -- ON = RAM, OFF Register

            overflow_checking => "ON",
            underflow_checking => "ON"
        )
        port map (
            clock => sys_clk,
            sclr => sys_rst_n,
            data => write_data,
            wrreq => write_enable,
            full => full,
            q => read_data,
            rdreq => read_enable,
            empty => empty,
            usedw => words_stored_slv
        );

    read_data_valid <= read_enable when rising_edge(sys_clk);
    words_stored <= to_integer(unsigned(words_stored_slv)) when not full else words_stored'subtype'high;
end architecture;

--!
--! @brief: This module is a generic FIFO memory block.
--! @note:  This module is technology independent and can be replaced with a technology specific sync FIFO module.
--! @note:  Use this if you don't have a technology specific sync FIFO.
--!
architecture own_behavioural_sync_fifo of fifo_sync is
    constant ADDR_WIDTH: natural := to_bits(FIFO_DEPTH - 1);

    signal write_pointer: unsigned(ADDR_WIDTH - 1 downto 0);
    signal read_pointer:  unsigned(ADDR_WIDTH - 1 downto 0);
    signal fifo_fill_level: unsigned(ADDR_WIDTH downto 0);

    signal fifo_read_request: std_ulogic;
    signal fifo_write_request: std_ulogic;
    signal write_address: std_ulogic_vector(write_pointer'range);
    signal read_address:  std_ulogic_vector(read_pointer'range);
begin
    -- assertion logic for simulation - not synthesised
    -- synthesis off
    ASSERTION_HINT: if UNDER_AND_OVERFLOW_ASSERTIONS generate
        fifo_overflow_underflow_assertion: process (sys_clk)
        begin
            if rising_edge(sys_clk) then
                if write_enable and full then
                    report "Assert Failure - FIFO is full and being written!" severity warning;
                end if;

                if read_enable and empty then
                    report "Assert Failure - FIFO is empty and being read!" severity warning;
                end if;
            end if;
        end process;
    end generate;
    -- synthesis on

    mem_status_proc: process (all)
    begin
        full <= '1' when fifo_fill_level >= FIFO_DEPTH else '0';
        empty <= '1' when fifo_fill_level = 0 else '0';
    end process;

    mem_req_proc: process (write_enable, read_enable, full, empty)
    begin
        fifo_write_request <= write_enable and not full;
        fifo_read_request <= read_enable and not empty;
    end process;

    fifo_ctrl_proc: process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                write_pointer <= (others => '0');
                read_pointer  <= (others => '0');
                fifo_fill_level <= (others => '0');
            else
                -- Handle simultaneous read/write operations correctly
                if fifo_write_request and fifo_read_request then
                    -- Simultaneous read and write - no change in fill level
                    write_pointer <= write_pointer + 1;
                    read_pointer <= read_pointer + 1;
                    -- fifo_fill_level remains unchanged
                elsif fifo_write_request then
                    -- Write only
                    write_pointer <= write_pointer + 1;
                    fifo_fill_level <= fifo_fill_level + 1;
                elsif fifo_read_request then
                    -- Read only
                    read_pointer <= read_pointer + 1;
                    fifo_fill_level <= fifo_fill_level - 1;
                end if;
            end if;
        end if;
    end process;

    words_stored <= FIFO_DEPTH when full else to_integer(fifo_fill_level);
    write_address <= std_ulogic_vector(write_pointer);
    read_address <= std_ulogic_vector(read_pointer);

    valid_flag_detect: process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                read_data_valid <= '0';
            else
                read_data_valid <= read_enable and not empty;
            end if;
        end if;
    end process;

    dual_port_ram_inst: entity work.dual_clock_dual_port_ram
        port map (
            write_clk => sys_clk,
            write_enable => fifo_write_request,
            write_data => write_data,
            write_address => write_address,
            read_clk => sys_clk,
            read_data => read_data,
            read_address => read_address
        );
end architecture;
