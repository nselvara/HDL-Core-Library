onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_spi_rx/spi_clk
add wave -noupdate /tb_spi_rx/rst_n
add wave -noupdate /tb_spi_rx/serial_data_in
add wave -noupdate /tb_spi_rx/spi_chip_select_n
add wave -noupdate -radix unsigned /tb_spi_rx/rx_data
add wave -noupdate /tb_spi_rx/rx_data_valid
add wave -noupdate -divider Internal
add wave -noupdate /tb_spi_rx/DUT/receiver/bit_index
add wave -noupdate -divider {tb - Internal}
add wave -noupdate -radix unsigned /tb_spi_rx/checker/current_bit_index
add wave -noupdate -radix unsigned /tb_spi_rx/checker/expected_data
add wave -noupdate /tb_spi_rx/spi_clk_enable
add wave -noupdate /tb_spi_rx/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {216558417 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
WaveRestoreZoom {0 ps} {336662550 ps}
