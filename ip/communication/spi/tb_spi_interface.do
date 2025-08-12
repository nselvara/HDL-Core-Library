onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_spi_interface/spi_clk_in
add wave -noupdate /tb_spi_interface/rst_n
add wave -noupdate -radix binary /tb_spi_interface/selected_chips
add wave -noupdate -radix unsigned /tb_spi_interface/tx_data
add wave -noupdate /tb_spi_interface/tx_data_valid
add wave -noupdate -radix unsigned /tb_spi_interface/rx_data
add wave -noupdate /tb_spi_interface/rx_data_valid
add wave -noupdate /tb_spi_interface/spi_clk_out
add wave -noupdate /tb_spi_interface/serial_data_out
add wave -noupdate /tb_spi_interface/serial_data_in
add wave -noupdate -radix binary /tb_spi_interface/spi_chip_select_n
add wave -noupdate /tb_spi_interface/tx_is_ongoing
add wave -noupdate -divider Internal
add wave -noupdate -expand -group tx /tb_spi_interface/DUT/spi_tx_inst/serial_data_out_internal
add wave -noupdate -expand -group tx -radix binary /tb_spi_interface/DUT/spi_tx_inst/spi_chip_select_n_internal
add wave -noupdate -expand -group tx /tb_spi_interface/DUT/spi_tx_inst/spi_fsm/state
add wave -noupdate -expand -group tx -radix unsigned /tb_spi_interface/DUT/spi_tx_inst/spi_fsm/bit_index
add wave -noupdate -expand -group tx -radix unsigned /tb_spi_interface/DUT/spi_tx_inst/spi_fsm/current_chip_index
add wave -noupdate -expand -group tx -radix binary /tb_spi_interface/DUT/spi_tx_inst/spi_fsm/selected_chips_reg
add wave -noupdate -expand -group tx -radix unsigned /tb_spi_interface/DUT/spi_tx_inst/spi_fsm/tx_data_reg
add wave -noupdate -expand -group rx -radix unsigned /tb_spi_interface/DUT/spi_rx_inst/receiver/bit_index
add wave -noupdate -divider {tb - Internal}
add wave -noupdate -radix binary /tb_spi_interface/expected_serial_data_out_and_chip_select_alignment/spi_chip_select_n_assertion
add wave -noupdate -radix binary /tb_spi_interface/expected_serial_data_out_and_chip_select_alignment/spi_chip_select_n_deassertion
add wave -noupdate /tb_spi_interface/serial_data_out_expected
add wave -noupdate /tb_spi_interface/serial_data_out_internal
add wave -noupdate -radix binary /tb_spi_interface/spi_chip_select_n_expected
add wave -noupdate -radix binary /tb_spi_interface/spi_chip_select_n_internal
add wave -noupdate /tb_spi_interface/loopback_enabled
add wave -noupdate /tb_spi_interface/spi_clk_enable
add wave -noupdate /tb_spi_interface/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4690000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 209
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {7655550 ps}
