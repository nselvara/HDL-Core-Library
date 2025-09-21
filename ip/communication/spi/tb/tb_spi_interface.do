onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_spi_interface/spi_clk_in
add wave -noupdate /tb_spi_interface/rst_n
add wave -noupdate -radix binary /tb_spi_interface/selected_chips
add wave -noupdate /tb_spi_interface/tx_fifo_write_enable
add wave -noupdate -radix unsigned /tb_spi_interface/tx_fifo_write_data
add wave -noupdate /tb_spi_interface/tx_fifo_write_blocked
add wave -noupdate /tb_spi_interface/tx_fifo_full
add wave -noupdate /tb_spi_interface/tx_fifo_empty
add wave -noupdate -radix unsigned /tb_spi_interface/tx_fifo_words_stored
add wave -noupdate /tb_spi_interface/tx_trigger
add wave -noupdate -radix unsigned /tb_spi_interface/rx_data
add wave -noupdate /tb_spi_interface/rx_data_valid
add wave -noupdate /tb_spi_interface/spi_clk_out
add wave -noupdate /tb_spi_interface/serial_data_out
add wave -noupdate /tb_spi_interface/serial_data_in
add wave -noupdate -radix binary /tb_spi_interface/spi_chip_select_n
add wave -noupdate /tb_spi_interface/spi_busy
add wave -noupdate -divider Internal
add wave -noupdate /tb_spi_interface/DUT/spi_chip_select_n_internal
add wave -noupdate -expand -group fsm /tb_spi_interface/DUT/state
add wave -noupdate -expand -group fsm -radix unsigned /tb_spi_interface/DUT/fsm/current_chip_index_v
add wave -noupdate -expand -group fsm -radix binary /tb_spi_interface/DUT/fsm/selected_chips_reg
add wave -noupdate -expand -group tx /tb_spi_interface/DUT/spi_tx_inst/serial_data_out_internal
add wave -noupdate -expand -group tx -label tx_spi_chip_select_n -radix binary /tb_spi_interface/DUT/spi_tx_inst/spi_chip_select_n_internal
add wave -noupdate -expand -group tx -radix unsigned /tb_spi_interface/DUT/spi_tx_inst/spi_tx_logic/tx_data_reg
add wave -noupdate -expand -group tx -radix unsigned /tb_spi_interface/DUT/spi_tx_inst/spi_tx_logic/bit_index
add wave -noupdate -expand -group tx /tb_spi_interface/DUT/spi_tx_inst/spi_tx_logic/tx_started
add wave -noupdate -expand -group rx -radix unsigned /tb_spi_interface/DUT/spi_rx_inst/receiver/bit_index
add wave -noupdate -expand -group {internal tx_fifo} /tb_spi_interface/DUT/tx_fifo_write_enable_internal
add wave -noupdate -expand -group {internal tx_fifo} /tb_spi_interface/DUT/tx_fifo_read_enable
add wave -noupdate -expand -group {internal tx_fifo} -radix unsigned /tb_spi_interface/DUT/tx_fifo_read_data
add wave -noupdate -expand -group {internal tx_fifo} /tb_spi_interface/DUT/tx_fifo_read_data_valid
add wave -noupdate -expand -group internal_tx_data /tb_spi_interface/DUT/tx_data_valid
add wave -noupdate -expand -group internal_tx_data /tb_spi_interface/DUT/tx_data_ack
add wave -noupdate -expand -group internal_tx_data -radix unsigned /tb_spi_interface/DUT/tx_data
add wave -noupdate -expand -group internal_tx_data /tb_spi_interface/DUT/tx_is_ongoing
add wave -noupdate -divider {tb - Internal}
add wave -noupdate -radix unsigned /tb_spi_interface/checker/expected_tx_data
add wave -noupdate -radix unsigned /tb_spi_interface/checker/expected_rx_data
add wave -noupdate -radix binary /tb_spi_interface/checker/expected_spi_chip_select_n
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
WaveRestoreCursors {{Cursor 1} {12518771 ps} 0}
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
WaveRestoreZoom {0 ps} {20875050 ps}
