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
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_interface is
    generic (
        SPI_CLK_POLARITY: bit := '0'; -- Clock polarity
        SPI_CLK_PHASE: bit := '0'; -- Clock phase
        SPI_CHIPS_AMOUNT: natural := 1; -- Number of SPI chips
        DATA_WIDTH: natural := 8; -- Width of the data bus
        CONTROLLER_AND_NOT_PERIPHERAL: boolean := true;
        MSB_FIRST_AND_NOT_LSB: boolean := true;
        ENABLE_INTERNAL_CLOCK_GATING: boolean := true;
        USE_XILINX_CLK_GATE_AND_NOT_INTERNAL: boolean := false -- Use Xilinx clock gating instead of internal logic
    );
    port (
        spi_clk_in: in std_ulogic;
        rst_n: in std_ulogic;

        selected_chips: in std_ulogic_vector;

        tx_data: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        tx_data_valid: in std_ulogic;

        rx_data: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rx_data_valid: out std_ulogic;

        spi_clk_out: out std_ulogic;
        serial_data_out: out std_logic;
        serial_data_in: in std_ulogic;
        spi_chip_select_n: inout std_ulogic_vector(SPI_CHIPS_AMOUNT - 1 downto 0);

        tx_is_ongoing: out std_ulogic
    );
end entity;

architecture behavioural of spi_interface is
begin
    spi_tx_inst: entity work.spi_tx
        generic map (
            SPI_CLK_POLARITY => SPI_CLK_POLARITY,
            SPI_CLK_PHASE => SPI_CLK_PHASE,
            SPI_CHIPS_AMOUNT => SPI_CHIPS_AMOUNT,
            DATA_WIDTH => DATA_WIDTH,
            CONTROLLER_AND_NOT_PERIPHERAL => CONTROLLER_AND_NOT_PERIPHERAL,
            MSB_FIRST_AND_NOT_LSB => MSB_FIRST_AND_NOT_LSB,
            ENABLE_INTERNAL_CLOCK_GATING => ENABLE_INTERNAL_CLOCK_GATING,
            USE_XILINX_CLK_GATE_AND_NOT_INTERNAL => USE_XILINX_CLK_GATE_AND_NOT_INTERNAL
        )
        port map (
            spi_clk_in => spi_clk_in,
            rst_n => rst_n,
            selected_chips => selected_chips,
            tx_data => tx_data,
            tx_data_valid => tx_data_valid,
            spi_clk_out => spi_clk_out,
            serial_data_out => serial_data_out,
            spi_chip_select_n => spi_chip_select_n,
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
            spi_chip_select_n => and(spi_chip_select_n),
            rx_data => rx_data,
            rx_data_valid => rx_data_valid
        );
end architecture;
