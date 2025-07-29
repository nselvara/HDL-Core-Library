--! 
--! @author:    N. Selvarajah
--! @brief:     This module describes a dual-port RAM module.
--! @details:   This module can be used by the programmer to store/read data.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dual_port_ram is
    port (
        sys_clk: in std_ulogic;
        sys_rst_n: in std_ulogic;
        en: in std_ulogic;
        write_enable: in std_ulogic;
        read_enable: in std_ulogic;
        write_address: in unsigned;
        read_address: in unsigned;
        write_data: in std_ulogic_vector;
        read_data: out std_ulogic_vector
    );
end entity;

architecture behavioural of dual_port_ram is
begin
    mem_operation_proc: process (sys_clk)
        constant RAM_DEPTH: positive := 2**write_address'length;
        subtype ram_depth_t is natural range 0 to RAM_DEPTH - 1;
        type ram_t is array (ram_depth_t) of write_data'subtype;
        variable ram_reg: ram_t;
    begin
        assert RAM_DEPTH <= natural'high report "ADDRESS_WIDTH exceeds the maximum allowed value!" severity error;

        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                -- NOTE: To infer Xilinx's BRAM, for Intel I don't know
                --       the reset can only be done one address a clock cycle  
                --       or the reset is completely left out whiich saves resources.
                read_data <= (read_data'range => '-');
            elsif en then
                if read_enable then
                    read_data <= ram_reg(to_integer(read_address));
                end if;
                -- NOTE: Don't move this block above the read block. 
                --       It will cause a read-before-write hazard.
                if write_enable then
                    ram_reg(to_integer(write_address)) := write_data;
                end if;
            end if;
        end if;
    end process;
end architecture;
