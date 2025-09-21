--!
--! @author:    N. Selvarajah
--! @brief:     This module describes the SPI Communication Interface with customisable parameters
--! @details:   It integrates both SPI TX and RX functionalities.
--!             The interface allows for configuration of clock polarity, phase, and data transmission order.
--!             It supports both controller and peripheral modes.
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

entity spi_interface is
    generic (
        SPI_CLK_POLARITY: bit := '0'; -- Clock polarity
        SPI_CLK_PHASE: bit := '0'; -- Clock phase
        SPI_CHIPS_AMOUNT: natural := 1; -- Number of SPI chips
        DATA_WIDTH: natural := 8; -- Width of the data bus
        CONTROLLER_AND_NOT_PERIPHERAL: boolean := true;
        MSB_FIRST_AND_NOT_LSB: boolean := true;
        ENABLE_INTERNAL_CLOCK_GATING: boolean := true;
        USE_XILINX_CLK_GATE_AND_NOT_INTERNAL: boolean := false;
        TX_FIFO_DEPTH_IN_BITS: natural := 4 -- Set to 0 for single-word mode
    );
    port (
        spi_clk_in: in std_ulogic;
        rst_n: in std_ulogic;

        selected_chips: in std_ulogic_vector(SPI_CHIPS_AMOUNT - 1 downto 0);

        tx_fifo_write_clk: in std_ulogic;
        tx_fifo_write_enable: in std_ulogic;
        tx_fifo_write_data: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        tx_fifo_write_blocked: out std_ulogic;
        tx_fifo_full: out std_ulogic;
        tx_fifo_empty: out std_ulogic;
        tx_fifo_words_stored: out natural range 0 to 2**TX_FIFO_DEPTH_IN_BITS;

        -- Streaming control
        tx_trigger: in std_ulogic;
        spi_busy: out std_ulogic;

        rx_data: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rx_data_valid: out std_ulogic;

        spi_clk_out: out std_ulogic;
        serial_data_out: out std_logic;
        serial_data_in: in std_ulogic;
        spi_chip_select_n: inout std_ulogic_vector(SPI_CHIPS_AMOUNT - 1 downto 0)
    );
end entity;

architecture behavioural of spi_interface is
    constant CHIP_INDEX_OUT_OF_RANGE: natural := selected_chips'length;
    signal current_chip_index: natural range 0 to CHIP_INDEX_OUT_OF_RANGE;

    -- FSM state
    type state_t is (idle, fetch_data, wait_for_data, wait_for_acknowledge, reset_for_next_chip, wait_for_transfer_end);
    signal state: state_t;

    -- FIFO signals
    signal tx_fifo_write_enable_internal: std_ulogic;

    signal tx_fifo_read_enable: std_ulogic;
    signal tx_fifo_read_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal tx_fifo_read_data_valid: std_ulogic;
    signal tx_fifo_reset_read_pointer: std_ulogic;

    -- TX interface signals
    signal tx_is_ongoing: std_ulogic;
    signal tx_data: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal tx_data_valid: std_ulogic;
    signal tx_data_ack: std_ulogic;

    signal spi_chip_select_n_internal: std_ulogic;
begin
    fsm: process (spi_clk_in)
        variable current_chip_index_v: current_chip_index'subtype;
        variable selected_chips_reg: selected_chips'subtype;

        -- Select only one chip at a time
        impure function get_next_selected_chip return natural is begin
            if current_chip_index_v >= CHIP_INDEX_OUT_OF_RANGE then
                return get_lowest_active_bit(selected_chips);
            end if;

            for i in spi_chip_select_n'subtype'low to spi_chip_select_n'subtype'high loop
                current_chip_index_v := current_chip_index_v + 1;
                -- Out of range or found the next active chip
                exit when current_chip_index_v >= CHIP_INDEX_OUT_OF_RANGE or (?? selected_chips_reg(current_chip_index_v));
            end loop;

            return current_chip_index_v;
        end function;
    begin
        if rising_edge(spi_clk_in) then
            tx_data_valid <= '0';
            tx_fifo_read_enable <= '0';
            tx_fifo_reset_read_pointer <= '0';
            spi_busy <= '1';

            if rst_n = '0' then
                tx_fifo_write_blocked <= '0';
                state <= idle;
                current_chip_index <= 0;
            else
                case state is
                    when idle =>
                        spi_busy <= '0';
                        tx_fifo_write_blocked <= '0';
                        current_chip_index_v := CHIP_INDEX_OUT_OF_RANGE;

                        if tx_trigger and not tx_fifo_empty  then
                            selected_chips_reg := selected_chips;
                            current_chip_index_v := get_next_selected_chip;
                            if current_chip_index_v /= CHIP_INDEX_OUT_OF_RANGE then
                                current_chip_index <= current_chip_index_v;
                                tx_fifo_write_blocked <= '1';
                                state <= fetch_data;
                            end if;
                        end if;
                    when fetch_data =>
                        if not tx_fifo_empty then
                            tx_fifo_read_enable <= '1';
                            state <= wait_for_data;
                        else
                            current_chip_index_v := get_next_selected_chip;
                            if current_chip_index_v /= CHIP_INDEX_OUT_OF_RANGE then
                                state <= reset_for_next_chip;
                            elsif not tx_is_ongoing then
                                state <= idle;  -- All chips done
                            else
                                state <= wait_for_transfer_end; -- Wait for ongoing transfer to finish
                            end if;
                        end if;
                    when wait_for_data =>
                        if tx_fifo_read_data_valid then
                            tx_data_valid <= '1';
                            tx_data <= tx_fifo_read_data;
                            state <= wait_for_acknowledge;
                        end if;
                    when wait_for_acknowledge =>
                        tx_data_valid <= '1';
                        if tx_data_ack then
                            state <= fetch_data;
                        end if;
                    when reset_for_next_chip =>
                        tx_fifo_reset_read_pointer <= '1';  -- Reset read pointer to replay data
                        current_chip_index <= current_chip_index_v;
                        if not tx_fifo_empty then
                            state <= fetch_data;
                        end if;
                    when wait_for_transfer_end =>
                        if not tx_is_ongoing then
                            state <= idle;  -- All chips done
                        end if;
                    when others =>
                        state <= idle;
                end case;
            end if;
        end if;
    end process;

    chip_select: process (all)
    begin
        spi_chip_select_n <= (others => '1');
        spi_chip_select_n(current_chip_index) <= spi_chip_select_n_internal;
    end process;

    tx_fifo_write_enable_internal <= rst_n and not tx_fifo_full and not tx_fifo_write_blocked and tx_fifo_write_enable;

    spi_tx_inst: entity work.spi_tx
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            DATA_WIDTH => DATA_WIDTH,
            CONTROLLER_AND_NOT_PERIPHERAL => CONTROLLER_AND_NOT_PERIPHERAL,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB,
            ENABLE_INTERNAL_CLOCK_GATING => ENABLE_INTERNAL_CLOCK_GATING,
            USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => USE_XILINX_CLK_GATE_AND_NOT_INTERNAL
        )
        port map (
            spi_clk_in => spi_clk_in,
            rst_n => rst_n,
            tx_data => tx_data,
            tx_data_valid => tx_data_valid,
            tx_data_ack => tx_data_ack,
            spi_clk_out => spi_clk_out,
            serial_data_out => serial_data_out,
            spi_chip_select_n => spi_chip_select_n_internal,
            tx_is_ongoing => tx_is_ongoing
        );

    spi_rx_inst: entity work.spi_rx
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            DATA_WIDTH => DATA_WIDTH,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB
        )
        port map (
            spi_clk => spi_clk_in,
            rst_n => rst_n,
            serial_data_in => serial_data_in,
            spi_chip_select_n => spi_chip_select_n_internal,
            rx_data => rx_data,
            rx_data_valid => rx_data_valid
        );

    fifo_async_inst: entity work.fifo_async(own_behavioural_async_fifo)
        generic map (
            FIFO_DEPTH_IN_BITS => TX_FIFO_DEPTH_IN_BITS,
            CDC_SYNC_STAGES => 2
        )
        port map (
            aclr => not rst_n,
            write_clk => tx_fifo_write_clk,
            read_clk => spi_clk_in,
            write_enable => tx_fifo_write_enable_internal,
            write_data => tx_fifo_write_data,
            read_enable => tx_fifo_read_enable,
            read_data => tx_fifo_read_data,
            read_data_valid => tx_fifo_read_data_valid,
            full => tx_fifo_full,
            empty => tx_fifo_empty,
            words_stored => tx_fifo_words_stored,
            reset_read_pointer => tx_fifo_reset_read_pointer
        );
end architecture;
