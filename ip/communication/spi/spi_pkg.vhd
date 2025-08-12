--!
--! @author:    N. Selvarajah
--! @brief:     This pkg contains utility functions and constants used in the project.
--! @details:
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package spi_pkg is
    generic (
        DATA_WIDTH: natural;
        MSB_FIRST_AND_NOT_LSB: boolean
    );

    subtype data_range_t is natural range 0 to DATA_WIDTH - 1;

    function active_edge_chip_select_n_assertion(signal clk_in: std_ulogic; clk_polarity: bit) return boolean;
    function active_edge_chip_select_n_deassertion(signal clk_in: std_ulogic; clk_polarity: bit) return boolean;
    function tx_active_edge(signal clk_in: std_ulogic; clk_polarity, clk_phase: bit) return boolean;
    function rx_active_edge(signal clk_in: std_ulogic; clk_polarity, clk_phase: bit) return boolean;
    function last_bit_index(bit_index: data_range_t) return boolean;
    procedure reset_bit_index(bit_index: inout data_range_t);
    procedure update_bit_index(bit_index: inout data_range_t);
end package;

package body spi_pkg is
    -- See the table: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface#Mode_numbers

    function active_edge_chip_select_n_assertion(signal clk_in: std_ulogic; clk_polarity: bit) return boolean is begin
        case clk_polarity is
            when '0' =>
                return falling_edge(clk_in);
            when '1' =>
                return true;
        end case;
    end function;

    function active_edge_chip_select_n_deassertion(signal clk_in: std_ulogic; clk_polarity: bit) return boolean is begin
        case clk_polarity is
            when '0' =>
                return rising_edge(clk_in);
            when '1' =>
                return falling_edge(clk_in);
        end case;
    end function;

    function tx_active_edge(signal clk_in: std_ulogic; clk_polarity, clk_phase: bit) return boolean is begin
        case clk_polarity & clk_phase is
            when "00" | "11" =>
                return falling_edge(clk_in);
            when "01" =>
                return rising_edge(clk_in);
            when "10" =>
                return true;
        end case;
    end function;

    function rx_active_edge(signal clk_in: std_ulogic; clk_polarity, clk_phase: bit) return boolean is begin
        case clk_polarity & clk_phase is
            when "00" =>
                return rising_edge(clk_in);
            when "01" =>
                return falling_edge(clk_in);
            when "10" =>
                return rising_edge(clk_in);
            when "11" =>
                return falling_edge(clk_in);
            when others =>
                return false; -- Default case, should not happen
        end case;
    end function;

    function last_bit_index(bit_index: data_range_t) return boolean is begin
        if MSB_FIRST_AND_NOT_LSB then
            return bit_index = bit_index'subtype'low;
        else
            return bit_index = bit_index'subtype'high;
        end if;
    end function;

    procedure reset_bit_index(bit_index: inout data_range_t) is begin
        bit_index := bit_index'subtype'high when MSB_FIRST_AND_NOT_LSB else bit_index'subtype'low;
    end procedure;

    procedure update_bit_index(bit_index: inout data_range_t) is begin
        if last_bit_index(bit_index) then
            reset_bit_index(bit_index);
            return;
        end if;

        bit_index := bit_index - 1 when MSB_FIRST_AND_NOT_LSB else bit_index + 1;
    end procedure;
end package body;
