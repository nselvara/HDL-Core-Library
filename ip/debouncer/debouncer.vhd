--! 
--! @author:    N. Selvarajah
--! @brief:     This module describes a debouncer.
--! @details:   Set DEBOUNCE_SYNC_BITS to the number of bits to shift the input signal to synchronize it with the clock.
--! @details:   10 ms is a good value for DEBOUNCE_SYNC_BITS.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;

entity debouncer is
    generic (
        DEBOUNCE_SYNC_BITS: natural range 0 to to_bits(natural'high) := 10;
        POLARITY: std_ulogic
    );
    port (
        clk_in: in std_ulogic;
        input: in std_ulogic;
        output: out std_ulogic
    );
end entity;

architecture behavioural of debouncer is
    signal debounce_counter: natural range 0 to 2**DEBOUNCE_SYNC_BITS - 1;
    signal input_sync: std_ulogic := not POLARITY;
    signal input_sync_d: std_ulogic := not POLARITY;
begin
    process (clk_in)
    begin
        if rising_edge(clk_in) then
            input_sync_d <= input;
            if input /= input_sync_d then
                debounce_counter <= 0;
            elsif debounce_counter < debounce_counter'subtype'high then
                debounce_counter <= debounce_counter + 1;
            else
                input_sync <= input;
                debounce_counter <= 0;
            end if;
        end if;
    end process;

    output <= input_sync;
end architecture;
