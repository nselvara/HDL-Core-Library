--!
--! @author:    N. Selvarajah
--! @brief:     This module describes a configurable number of flip-flops in the synchronisation chain.
--! @details:   This module is a wrapper for the Xilinx XPM CDC block.
--! @details:   Thus, it won't work with other synthesis tools.
--!
--! @license This project is released under the terms of the MIT License. See LICENSE for more details.
--!

library ieee;
use ieee.std_logic_1164.all;

entity ff_synchroniser_vector is
    generic (
        DEST_SYNC_FF: positive range 2 to 10 := 4;
        SIM_INIT_SYNC_FF: boolean := false;     --! false=disable simulation init values, true=enable simulation init values
        SIM_ASSERT_CHK: boolean := false;   --! false=disable simulation messages, true=enable simulation messages
        SRC_INPUT_REG: boolean := true      --! false=do not register input, true=register input (to catch combinatorial logic)
    );
    port (
        source_clk: in std_ulogic;
        destination_clk: in std_ulogic;

        in_data: in std_ulogic_vector;
        in_data_valid: in std_ulogic;
        out_data: out std_ulogic_vector;
        out_data_valid: out std_ulogic
    );
end entity;

Library xpm;
use xpm.vcomponents.all;

architecture xilinx_behavioural_ff_synchroniser_vector of ff_synchroniser_vector is
    signal sync_chain_out: std_ulogic_vector(in_data'length downto 0); -- +1 for the valid bit
begin
    out_data_valid <= sync_chain_out(in_data'high + 1);
    out_data <= sync_chain_out(out_data'range);

    xpm_cdc_array_single_inst: xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => DEST_SYNC_FF,
            INIT_SYNC_FF => boolean'pos(SIM_INIT_SYNC_FF),
            SIM_ASSERT_CHK => boolean'pos(SIM_ASSERT_CHK),
            SRC_INPUT_REG => boolean'pos(SRC_INPUT_REG),
            WIDTH => sync_chain_out'length
        )
        port map (
            src_clk => source_clk,
            dest_clk => destination_clk,
            src_in => in_data_valid & in_data,
            dest_out => sync_chain_out
    );
end architecture;

--!
--! @brief: This module is a generic synchroniser that can be used to cross clock domains.
--! @note:  This module is a technology specific synchroniser, however, it can be used technology independent, where the altera_attribute can be ignored.
--! @note:  The FFs should be placed together to get a reliable crossing.
--! @note:  Use this if you don't have a technology specific synchroniser.
--!
architecture intel_behavioural_ff_synchroniser_vector of ff_synchroniser_vector is
    signal meta_stable_data_reg: in_data'subtype;
    signal meta_stable_valid_reg: std_ulogic;

    type in_data_arr_t is array (DEST_SYNC_FF - 2 downto 0) of in_data'subtype; -- -2: Including meta_stable_reg
    signal sync_chain_data: in_data_arr_t;
    signal sync_chain_valid: std_ulogic_vector(in_data_arr_t'range);

    signal source_data_registered: in_data'subtype;
    signal source_valid_registered: std_ulogic;

    attribute altera_attribute: string;
    attribute altera_attribute of meta_stable_data_reg: signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";
    -- Apply a SDC constraint to meta stable flip flop
    attribute altera_attribute of intel_behavioural_ff_synchroniser_vector: architecture is "-name SDC_STATEMENT ""set_false_path -to [get_registers {*|sync_chain_in_dst_dom_proc:*|:meta_stable_data_reg}] """;

    -- set 'preserve' attribute to src_reg and sync_chain -> the synthesis tool doesn't optimise them away
    attribute preserve: boolean;
    attribute preserve of meta_stable_data_reg: signal is true;
    attribute preserve of meta_stable_valid_reg: signal is true;
    attribute preserve of sync_chain_data: signal is true;
    attribute preserve of sync_chain_valid: signal is true;
begin
    -- Catch the incoming signal in the source domain to ensure
    -- there are no combinatorial elements before crossing
    comb_reg_source_dom_proc: process (source_clk)
    begin
        if rising_edge(source_clk) then
            source_data_registered <= in_data;
            source_valid_registered <= in_data_valid;
        end if;
    end process;

    -- N bits sync chain in the sync_chain_ domain
    sync_chain_in_dst_dom_proc: process (destination_clk)
    begin
        if rising_edge(destination_clk) then
            meta_stable_data_reg <= source_data_registered;  -- First element of the sync chain
            meta_stable_valid_reg <= source_valid_registered;
            sync_chain_data <= sync_chain_data(sync_chain_data'high - 1 downto sync_chain_data'low) & meta_stable_data_reg;
            sync_chain_valid <= sync_chain_valid(sync_chain_valid'high - 1 downto sync_chain_valid'low) & meta_stable_valid_reg;
        end if;
    end process;

    out_data <= sync_chain_data(sync_chain_data'high);
    out_data_valid <= sync_chain_valid(sync_chain_valid'high);
end architecture;
