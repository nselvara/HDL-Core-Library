--! 
--! @author:    N. Selvarajah
--! @brief:     This module describes a single-port RAM module.
--! @details:   This module can be used by the programmer to store/read data.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_port_ram is
    port (
        sys_clk: in std_ulogic;
        sys_rst_n: in std_ulogic;
        en: in std_ulogic;
        write_and_not_read: in std_ulogic;
        address: in unsigned;
        write_data: in std_ulogic_vector;
        read_data: out std_ulogic_vector
    );
end entity;

architecture behavioural of single_port_ram is
    constant RAM_DEPTH: positive := 2**address'length;
    subtype ram_depth_t is natural range 0 to RAM_DEPTH - 1;
    type ram_t is array (ram_depth_t) of write_data'subtype;

    signal write_enable: std_ulogic;
    signal read_enable: std_ulogic;

    signal ram_reg: ram_t;
begin
    mem_control_proc: process (write_and_not_read)
    begin
        write_enable <= write_and_not_read;
        read_enable <= not write_and_not_read;
    end process;

    mem_operation_proc: process (sys_clk)
        variable address_v: ram_depth_t;
    begin
        assert RAM_DEPTH <= natural'high report "ADDRESS_WIDTH exceeds the maximum allowed value!" severity error;

        address_v := to_integer(address);

        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                -- NOTE: To infer Xilinx's BRAM, for Intel I don't know
                --       the reset can only be done one address a clock cycle  
                --       or the reset is completely left out whiich saves resources.
                null;
            elsif en then
                if write_enable then
                    ram_reg(address_v) <= write_data;
                elsif read_enable then
                    read_data <= ram_reg(address_v);
                end if;
            end if;
        end if;
    end process;
end architecture;
