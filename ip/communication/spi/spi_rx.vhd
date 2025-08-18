--!
--! @author:    N. Selvarajah
--! @brief:     This module describes the SPI RX part of the SPI communication interface.
--!
--! @note:      The SPI_CLK_POLARITY and SPI_CLK_PHASE parameters determine the clock behavior.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_rx is
    generic (
        SPI_CLK_POLARITY: bit := '0'; -- Clock polarity
        SPI_CLK_PHASE: bit := '0'; -- Clock phase
        DATA_WIDTH: natural := 8;
        MSB_FIRST_AND_NOT_LSB: boolean := true
    );
    port (
        spi_clk: in std_ulogic;
        rst_n: in std_ulogic;

        serial_data_in: in std_logic;
        spi_chip_select_n: in std_ulogic;

        rx_data: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rx_data_valid: out std_ulogic
    );
end entity;

architecture behavioural of spi_rx is
    package spi_pkg_constrained is new work.spi_pkg
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        );
    use spi_pkg_constrained.all;
begin
    receiver: process (spi_clk)
        variable bit_index: natural range 0 to rx_data'subtype'high;
    begin
        if rx_active_edge(spi_clk, SPI_CLK_POLARITY, SPI_CLK_PHASE) then
            rx_data_valid <= '0';
            rx_data(bit_index) <= serial_data_in;

            if rst_n = '0' or spi_chip_select_n = '1' then
                reset_bit_index(bit_index);
            elsif spi_chip_select_n = '0' then
                -- NOTE: Order of operations is important here
                if last_bit_index(bit_index) then
                    rx_data_valid <= '1';
                end if;
                update_bit_index(bit_index);
            end if;
        end if;
    end process;
end architecture;
