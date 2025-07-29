--!
--! @author:    N. Selvarajah
--! @brief:     This module describes a reset controller that's being asserted during startup and de-asserted after configurable time.
--! @brief:     Plus it acts as a passthrough (with 1 clk cycle delay) for the reset signal.
--!
--! @license    This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

entity reset_on_startup is
    generic (
        RESET_TIME_IN_CLK_CYCLES: positive := 2;
        RESET_POLARITY: std_ulogic := '0'  -- '0' for active low, '1' for active high
    );
    port (
        clk: in std_ulogic;
        rst_in: in std_ulogic;
        rst_out: out std_ulogic
    );
end entity;

architecture behavioural of reset_on_startup is
    signal reset_on_startup: std_ulogic := RESET_POLARITY;  -- Initialise to active reset
    signal rst_delayed: std_ulogic := RESET_POLARITY;       -- Initialise to active reset

    -- NOTE: These attributes are used to prevent synthesis tools from optimising the reset signal away
    -- Xilinx attribute for preventing optimisation
    attribute dont_touch: string;
    attribute dont_touch of rst_delayed: signal is "true";

    -- Intel/Altera attribute for preventing optimisation
    attribute preserve: boolean;
    attribute preserve of rst_delayed: signal is true;
begin
    -- Combine the delayed input reset with the startup reset
    -- When either is active (matches RESET_POLARITY), output is active
    rst_out <= RESET_POLARITY when (rst_delayed = RESET_POLARITY or reset_on_startup = RESET_POLARITY) else
               not RESET_POLARITY;

    -- Should only utilise one FF
    reset_controller: process (clk)
        variable startup_counter: natural range 0 to RESET_TIME_IN_CLK_CYCLES := 0;
    begin
        if rising_edge(clk) then
            -- `rst_delayed` holds the fan-out at a reasonable level,
            --  as as the consumers of this (local) reset are expected to be interconnected tightly anyhow
            rst_delayed <= rst_in;

            if startup_counter < startup_counter'subtype'high then
                startup_counter := startup_counter + 1;
            end if;

            if startup_counter = startup_counter'subtype'high then
                reset_on_startup <= not RESET_POLARITY;  -- Release reset on next cycle
            end if;
        end if;
    end process;
end architecture;
