--! 
--! @author:    N. Selvarajah
--! @brief:     This module describes a ROM module.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.memories_pkg.all;

entity rom is
    generic (
        DATA_WIDTH: positive := 8;
        MEM_INIT_FILE_PATH: string := "";
        SIMULATION_MODE: boolean := false
    );
    port (
        sys_clk: in std_ulogic;
        sys_rst_n: in std_ulogic;
        address: in unsigned;
        q: out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity;

architecture behavioural of rom is
    constant ROM_DEPTH: natural := 2**address'length;
    subtype rom_depth_t is natural range 0 to ROM_DEPTH - 1;

    impure function load_rom(path: string) return rom_t is
        file instructions_file: text;
        variable address: rom_depth_t;
        variable rom_reg: rom_t(rom_depth_t)(q'range) := (others => (others => '0'));
        variable row: line;
    begin
        if path'length = 0 then
            assert false report "No memory initialisation file provided!" severity warning;
            return rom_reg;
        end if;

        file_open(instructions_file, path, read_mode);
        -- We on purpose don't check address overflow here, as an assert
        -- should warn the user if the file is too big.
        while not endfile(instructions_file) loop
            readline(instructions_file, row);
            hread(row, rom_reg(address));
            address := address + 1;
        end loop;

        file_close(instructions_file);
        return rom_reg;
    end function;

    constant rom_reg: rom_t := load_rom(path => MEM_INIT_FILE_PATH);
    -- Only for simulation purpose as it's overriddable via force
    signal rom_reg_only_for_simulation: rom_reg'subtype := (others => (others => '0'));
begin
    mem_operation_proc: process (sys_clk)
    begin
        assert ROM_DEPTH <= natural'high report "ADDRESS_WIDTH exceeds the maximum allowed value!" severity error;

        if rising_edge(sys_clk) then
            if sys_rst_n = '0' then
                q <= (others => '0');
            else
                -- We're not using if generate here, as it can be declared only outside of a process adn we don't want to have duplicated code.
                if not SIMULATION_MODE then
                    q <= rom_reg(to_integer(address));
                else
                    q <= rom_reg_only_for_simulation(to_integer(address));
                end if;
            end if;
        end if;
    end process;
end architecture;
