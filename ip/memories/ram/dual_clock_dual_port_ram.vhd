--! 
--! @author:    N. Selvarajah
--! @brief:     This module describes a dual-clock dual-port RAM module for FIFO use.
--! @details:   This module can be used in asynchronous FIFOs where read and write operate on different clocks.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dual_clock_dual_port_ram is
    port (
        write_clk: in std_ulogic;
        write_enable: in std_ulogic;
        write_data: in std_ulogic_vector;
        write_address: in std_ulogic_vector;
        read_clk: in std_ulogic;
        read_data: out std_ulogic_vector;
        read_address: in std_ulogic_vector
    );
end entity;

architecture behavioural of dual_clock_dual_port_ram is
    subtype ram_depth_t is natural range 2**write_address'length - 1 downto 0;
    type ram_t is array (ram_depth_t) of write_data'subtype;

    signal ram_reg: ram_t;
begin
    write_process: process (write_clk)
    begin
        if rising_edge(write_clk) then
            if write_enable then
                ram_reg(to_integer(unsigned(write_address))) <= write_data;
            end if;
        end if;      
    end process;

    read_process: process (read_clk)
    begin
        if rising_edge(read_clk) then
            read_data <= ram_reg(to_integer(unsigned(read_address)));
        end if;
    end process;
end architecture;
