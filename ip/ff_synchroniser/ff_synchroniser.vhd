--!
--! @author:    N. Selvarajah
--! @brief:     This module describes a configurable number of flip-flops in the synchronisation chain.
--! @details:   This module is a generic synchroniser that can be used to cross clock domains.
--! @details:   The module is configurable to set the length of the synchronisation chain to achieve the desired MTF. The module is designed to be technology independent and can be replaced with a technology specific synchroniser module.
--! @note:      Replace this module with an appropriate one for the target technology: Xilinx, Intel, Technology Independent
--! @note:      E.g. XPM_CDC for Xilinx or add the required attributes to identify the module as a synchroniser e.g. SYNCHRONIZER_IDENTIFICATION for Altera.
--! @note:      The FFs should be placed together to get a reliable crossing.
--! @note:      If the Xilinx technology specific synchroniser is used, deactivate by `SRC_INPUT_REG = 0`
--!             This means that the input is not registered which in turn means that the source_clk is not necessary.
--! @note:      In order to out a limit on the delay of the path comin into the CDC, use the following command in the xdc file:
--!             set_max_delay -datapath_only
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

entity ff_synchroniser is
    generic (
        SYNC_SHIFT_FF: positive range 2 to 10 := 4; --! Flip Flops to sync: Range: 2-10
        INIT_SYNC_FF: boolean := false;             --! false=disable simulation init values, true=enable simulation init values
        SIM_ASSERT_MSG: boolean := false;           --! false=disable simulation messages, true=enable simulation messages
        SRC_INPUT_REG: boolean := true              --! false=do not register input, true=register input (to catch combinatorial logic)
    );
    port (
        source_clk: in std_ulogic;
        destination_clk: in std_ulogic;
        source_domain: in std_ulogic;
        destination_domain: out std_ulogic
    );
end entity;

library xpm;
use xpm.vcomponents.all;

--!
--! @brief: This module is a Xilinx technology specific synchroniser that can be used to cross clock domains.
--! @note:  This module is a wrapper for the XPM_CDC module.
--! @note:  Use this primarily for Xilinx technology.
--!
architecture xilinx_behavioural_ff_synchroniser of ff_synchroniser is
begin
    xpm_cdc_single_sync_inst: xpm_cdc_single
        generic map (
            DEST_SYNC_FF => SYNC_SHIFT_FF,
            INIT_SYNC_FF => boolean'pos(INIT_SYNC_FF),
            SIM_ASSERT_CHK => boolean'pos(SIM_ASSERT_MSG),
            SRC_INPUT_REG => boolean'pos(SRC_INPUT_REG)
        )
        port map (
            src_clk => source_clk,
            src_in => source_domain,
            dest_clk => destination_clk,
            dest_out => destination_domain
        );
end architecture;

--!
--! @brief: This module is a synchroniser for Intel based FPGAs that can be used to cross clock domains.
--! @note:  This module is a technology specific synchroniser, however, it can be used technology independent, where the altera_attribute can be ignored.
--! @note:  The FFs should be placed together to get a reliable crossing.
--! @note:  Use this if you don't have a technology specific synchroniser.
--!
architecture intel_behavioural_ff_synchroniser of ff_synchroniser is
    signal src_reg: std_ulogic;
    signal meta_stable_reg: std_ulogic;
    signal sync_chain: std_ulogic_vector(SYNC_SHIFT_FF - 2 downto 0); --! -2: Include meta_stable_reg as first element

    attribute altera_attribute: string;
    attribute altera_attribute of src_reg: signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";
    -- Apply a SDC constraint to meta stable flip flop
    attribute altera_attribute of intel_behavioural_ff_synchroniser: architecture is "-name SDC_STATEMENT ""set_false_path -to [get_registers {*|sync_chain_in_dst_dom_proc:*|:meta_stable_reg}] """;

    -- set 'preserve' attribute to src_reg and sync_chain -> the synthesis tool doesn't optimise them away
    attribute preserve: boolean;
    attribute preserve of src_reg: signal is true;
    attribute preserve of sync_chain: signal is true;
begin
    -- Catch the incoming signal in the source domain to ensure
    -- there are no combinatorial elements before crossing
    comb_reg_source_domain_proc: process (source_clk)
    begin
        if rising_edge(source_clk) then
            src_reg <= source_domain;
        end if;
    end process;

    -- N bits sync chain in the destination domain
    sync_chain_in_dst_dom_proc: process (destination_clk)
    begin
        if rising_edge(destination_clk) then
            meta_stable_reg <= src_reg;  -- First element of the sync chain
            sync_chain <= sync_chain(sync_chain'high - 1 downto sync_chain'low) & meta_stable_reg;
        end if;
    end process;

    destination_domain <= sync_chain(sync_chain'high);
end architecture;
