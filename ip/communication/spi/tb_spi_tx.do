onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_spi_tx/spi_clk
add wave -noupdate /tb_spi_tx/rst_n
add wave -noupdate /tb_spi_tx/spi_clk_out
add wave -noupdate -radix binary /tb_spi_tx/selected_chips
add wave -noupdate -radix unsigned /tb_spi_tx/tx_data
add wave -noupdate /tb_spi_tx/tx_data_valid
add wave -noupdate -radix unsigned /tb_spi_tx/serial_data_out
add wave -noupdate -radix binary /tb_spi_tx/spi_chip_select_n
add wave -noupdate /tb_spi_tx/tx_is_ongoing
add wave -noupdate -divider Internal
add wave -noupdate -expand -group fsm /tb_spi_tx/DUT/spi_fsm/state
add wave -noupdate -expand -group fsm -radix unsigned /tb_spi_tx/DUT/spi_fsm/bit_index
add wave -noupdate -expand -group fsm -radix unsigned /tb_spi_tx/DUT/spi_fsm/current_chip_index
add wave -noupdate -expand -group fsm -radix binary /tb_spi_tx/DUT/spi_fsm/selected_chips_reg
add wave -noupdate -expand -group fsm -radix unsigned /tb_spi_tx/DUT/spi_fsm/tx_data_reg
add wave -noupdate -radix binary /tb_spi_tx/DUT/serial_data_out_and_chip_select_alignment/spi_chip_select_n_assertion
add wave -noupdate -radix binary /tb_spi_tx/DUT/serial_data_out_and_chip_select_alignment/spi_chip_select_n_deassertion
add wave -noupdate -radix unsigned /tb_spi_tx/DUT/serial_data_out_internal
add wave -noupdate -radix binary /tb_spi_tx/DUT/spi_chip_select_n_internal
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_spi_tx/spi_clk_enable
add wave -noupdate /tb_spi_tx/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {790376 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 202
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
WaveRestoreZoom {0 ps} {2111550 ps}
