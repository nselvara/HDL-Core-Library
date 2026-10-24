--!
--! @author:    N. Selvarajah
--! @brief:     FIFO package
--! @details:   Helpers for the FIFO wrappers, e.g. building the Xilinx XPM
--!             USE_ADV_FEATURES configuration string.
--!
--! @license    This project is released under the terms of the GNU GENERAL PUBLIC LICENSE v3. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

package fifo_pkg is
    -- Builds the USE_ADV_FEATURES hex string for the Xilinx XPM FIFO (PG057):
    --   [0]  overflow
    --   [1]  prog_full
    --   [2]  wr_data_count
    --   [3]  almost_full
    --   [4]  wr_ack
    --   [8]  underflow
    --   [9]  prog_empty
    --   [10] rd_data_count
    --   [11] almost_empty
    --   [12] data_valid
    -- Bits 5 to 7 and 13 to 15 are reserved.
    function use_advanced_features(
        enable_overflow : boolean := false;
        enable_prog_full : boolean := false;
        enable_wr_data_count : boolean := false;
        enable_almost_full : boolean := false;
        enable_wr_ack : boolean := false;
        enable_underflow : boolean := false;
        enable_prog_empty : boolean := false;
        enable_rd_data_count : boolean := false;
        enable_almost_empty : boolean := false;
        enable_data_valid : boolean := false
    ) return string;
end package;

package body fifo_pkg is
    function use_advanced_features(
        enable_overflow : boolean := false;
        enable_prog_full : boolean := false;
        enable_wr_data_count : boolean := false;
        enable_almost_full : boolean := false;
        enable_wr_ack : boolean := false;
        enable_underflow : boolean := false;
        enable_prog_empty : boolean := false;
        enable_rd_data_count : boolean := false;
        enable_almost_empty : boolean := false;
        enable_data_valid : boolean := false
    ) return string is
        constant REGISTER_WIDTH : natural := 13;
        variable settings : std_ulogic_vector(REGISTER_WIDTH - 1 downto 0) := (others => '0');
    begin
        if enable_overflow then
            settings(0) := '1';
        end if;
        if enable_prog_full then
            settings(1) := '1';
        end if;
        if enable_wr_data_count then
            settings(2) := '1';
        end if;
        if enable_almost_full then
            settings(3) := '1';
        end if;
        if enable_wr_ack then
            settings(4) := '1';
        end if;
        if enable_underflow then
            settings(8) := '1';
        end if;
        if enable_prog_empty then
            settings(9) := '1';
        end if;
        if enable_rd_data_count then
            settings(10) := '1';
        end if;
        if enable_almost_empty then
            settings(11) := '1';
        end if;
        if enable_data_valid then
            settings(12) := '1';
        end if;

        return to_hstring(settings);
    end function;
end package body;
