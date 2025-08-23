--!
--! @author:    N. Selvarajah
--! @brief:     This module describes the SPI TX part of the SPI communication interface.
--!
--! @note:      The SPI_CLK_POLARITY and SPI_CLK_PHASE parameters determine the clock behavior.
--! @note:      Vendor-specific clock handling recommendations:
--!
--!             For Xilinx FPGAs:
--!             - Set ENABLE_INTERNAL_CLOCK_GATING to true
--!             - For global clock networks, set USE_XILINX_CLK_GATE_AND_NOT_INTERNAL to true to use BUFGCE
--!             - For local clock networks, USE_XILINX_CLK_GATE_AND_NOT_INTERNAL can be false for regular gating
--!
--!             For Intel/Altera FPGAs:
--!             - Set ENABLE_INTERNAL_CLOCK_GATING to false to avoid direct clock gating
--!             - Always set USE_XILINX_CLK_GATE_AND_NOT_INTERNAL to false
--!             - Instead of clock gating:
--!               1. Use the enable pin on Intel PLLs to control clock generation at the source
--!               2. Use register enable pins throughout your design instead of gating the clock
--!               3. If implementing the SPI controller, consider using clock enables at registers
--!                  rather than gating the SPI clock output
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;

entity spi_tx is
    generic (
        SPI_CLK_POLARITY: bit := '0'; -- Clock polarity
        SPI_CLK_PHASE: bit := '0'; -- Clock phase
        SPI_CHIPS_AMOUNT: natural := 1;
        DATA_WIDTH: natural := 8;
        CONTROLLER_AND_NOT_PERIPHERAL: boolean := true;
        MSB_FIRST_AND_NOT_LSB: boolean := true;
        ENABLE_INTERNAL_CLOCK_GATING: boolean := true;
        USE_XILINX_CLK_GATE_AND_NOT_INTERNAL: boolean := false
    );
    port (
        spi_clk_in: in std_ulogic;
        rst_n: in std_ulogic;

        selected_chips: in std_ulogic_vector;

        tx_data: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        tx_data_valid: in std_ulogic;

        spi_clk_out: out std_ulogic;
        serial_data_out: out std_logic; -- For tri-state output
        spi_chip_select_n: inout std_ulogic_vector(SPI_CHIPS_AMOUNT - 1 downto 0);

        tx_is_ongoing: out std_ulogic
    );
end entity;

architecture behavioural of spi_tx is
    package spi_pkg_constrained is new work.spi_pkg
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        );
    use spi_pkg_constrained.all;

    signal serial_data_out_internal: std_logic;
    signal spi_chip_select_n_internal: spi_chip_select_n'subtype;
begin
    spi_fsm: process (spi_clk_in)
        type state_t is (idle, transmission, wait_for_chip_selects_deassertion);

        constant CHIP_INDEX_OUT_OF_RANGE: natural := selected_chips'length;

        variable state: state_t;

        variable bit_index: natural range 0 to tx_data'subtype'high;
        variable current_chip_index: natural range 0 to CHIP_INDEX_OUT_OF_RANGE;

        variable selected_chips_reg: selected_chips'subtype;
        variable tx_data_reg: tx_data'subtype;

        -- Select only one chip at a time
        impure function select_next_chip_index return natural is begin
            if current_chip_index >= CHIP_INDEX_OUT_OF_RANGE then
                return get_lowest_active_bit(selected_chips);
            end if;

            for i in spi_chip_select_n'subtype'low to spi_chip_select_n'subtype'high loop
                current_chip_index := current_chip_index + 1;
                -- Out of range or found the next active chip
                exit when current_chip_index >= CHIP_INDEX_OUT_OF_RANGE or (?? selected_chips_reg(current_chip_index));
            end loop;

            return current_chip_index;
        end function;
    begin
        if rising_edge(spi_clk_in) then
            tx_is_ongoing <= '0';
            serial_data_out_internal <= 'Z';
            spi_chip_select_n_internal <= (others => '1');

            if rst_n = '0' then
                state := idle;
                current_chip_index := CHIP_INDEX_OUT_OF_RANGE;
                reset_bit_index(bit_index);
            else
                case state is
                    when idle =>
                        selected_chips_reg := selected_chips;

                        if tx_data_valid then
                            tx_data_reg := tx_data;
                            current_chip_index := select_next_chip_index;

                            if current_chip_index /= CHIP_INDEX_OUT_OF_RANGE then
                                state := transmission;
                            end if;
                        end if;
                    when transmission =>
                        tx_is_ongoing <= '1';
                        serial_data_out_internal <= tx_data_reg(bit_index);
                        spi_chip_select_n_internal(current_chip_index) <= '0';

                        if last_bit_index(bit_index) then
                            current_chip_index := select_next_chip_index; -- Move to the next chip

                            if current_chip_index >= CHIP_INDEX_OUT_OF_RANGE then
                                state := idle; -- Finished transmission for all chips
                            else
                                state := wait_for_chip_selects_deassertion;
                            end if;
                        end if;

                        -- This construct should optimise current_chip_index and spi_chip_select_n_internal away
                        if CONTROLLER_AND_NOT_PERIPHERAL or (not CONTROLLER_AND_NOT_PERIPHERAL and (and(spi_chip_select_n) = '0')) then
                            update_bit_index(bit_index);
                        end if;
                    when wait_for_chip_selects_deassertion =>
                        tx_is_ongoing <= '1';

                        if and(spi_chip_select_n) = '1' then
                            state := transmission;
                        end if;
                    when others =>
                        state := idle;
                end case;
            end if;
        end if;
    end process;

    -- NOTE: Xilinx doesn't recognise generic functions that have the same definitions like rising_edge/falling_edge, thus, it creates latches instead of FFs
    -- So we've to manually state for which SPI mode at what edge has to be sampled.
    -- With Intel the previous solution worked perfectly
    serial_data_out_and_chip_select_alignment: block
        signal spi_chip_select_n_assertion: spi_chip_select_n'subtype;
        signal spi_chip_select_n_deassertion: spi_chip_select_n'subtype;
    begin
        serial_data_out_alignment: case SPI_CLK_POLARITY & SPI_CLK_PHASE generate
            when "00" | "11" =>
                alignment: process (spi_clk_in)
                begin
                    if falling_edge(spi_clk_in) then
                        serial_data_out <= serial_data_out_internal;
                    end if;
                end process;
            when "01" =>
                postpone: process (spi_clk_in)
                begin
                    if rising_edge(spi_clk_in) then
                        serial_data_out <= serial_data_out_internal;
                    end if;
                end process;
            when "10" =>
                pass_through: serial_data_out <= serial_data_out_internal;
        end generate;

        chip_select_n_driver: if CONTROLLER_AND_NOT_PERIPHERAL generate
            spi_chip_select_n_alignment: case SPI_CLK_POLARITY generate
                when '0' =>
                    alignment: process (spi_clk_in)
                    begin
                        if falling_edge(spi_clk_in) then
                            spi_chip_select_n_assertion <= spi_chip_select_n_internal;
                        elsif rising_edge(spi_clk_in) then
                            spi_chip_select_n_deassertion <= spi_chip_select_n_internal;
                        end if;
                    end process;
                when '1' =>
                    alignment: process (spi_clk_in)
                    begin
                        pass_through: spi_chip_select_n_assertion <= spi_chip_select_n_internal;

                        if falling_edge(spi_clk_in) then
                            spi_chip_select_n_deassertion <= spi_chip_select_n_internal;
                        end if;
                    end process;
            end generate;

            spi_chip_select_n <= spi_chip_select_n_assertion and spi_chip_select_n_deassertion;
        end generate;
    end block;

    -- SPI clock driver implementation with vendor-specific considerations
    spi_clk_driver: if CONTROLLER_AND_NOT_PERIPHERAL generate
        -- Clock enable instantiation for SPI clock output generation
        -- NOTE: For Intel/Altera FPGAs:
        -- 1. Set ENABLE_INTERNAL_CLOCK_GATING to false to avoid direct clock gating
        -- 2. Instead use register enable pins throughout the design
        -- 3. Or enable/disable the PLL outputs at the clock source
        spi_clk_enable_inst: entity work.clock_enable
            generic map (
                -- Set to false for Intel/Altera FPGAs
                ENABLE_INTERNAL_CLOCK_GATING => ENABLE_INTERNAL_CLOCK_GATING,
                -- Only set to true for Xilinx FPGAs with BUFGCE
                USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => USE_XILINX_CLK_GATE_AND_NOT_INTERNAL
            )
            port map (
                clk_in => spi_clk_in,
                clk_enable => not (and(spi_chip_select_n)),
                clk_out => spi_clk_out
            );
    else generate
        spi_clk_out <= '-';
    end generate;
end architecture;
