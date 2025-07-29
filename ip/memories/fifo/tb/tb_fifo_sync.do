onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {DuT - Interfaces}
add wave -noupdate /tb_fifo_sync/sys_clk
add wave -noupdate /tb_fifo_sync/sys_rst_n
add wave -noupdate /tb_fifo_sync/write_enable
add wave -noupdate /tb_fifo_sync/read_enable
add wave -noupdate -divider Xilinx
add wave -noupdate /tb_fifo_sync/full_xilinx
add wave -noupdate /tb_fifo_sync/empty_xilinx
add wave -noupdate -divider Own
add wave -noupdate /tb_fifo_sync/full_own
add wave -noupdate /tb_fifo_sync/empty_own
add wave -noupdate -divider RAM
add wave -noupdate -divider {DuT Own - Internal}
add wave -noupdate -radix unsigned /tb_fifo_sync/DuT_own/fifo_fill_level
add wave -noupdate -radix unsigned /tb_fifo_sync/DuT_own/write_pointer
add wave -noupdate -radix unsigned /tb_fifo_sync/DuT_own/read_pointer
add wave -noupdate /tb_fifo_sync/DuT_own/fifo_read_request
add wave -noupdate /tb_fifo_sync/DuT_own/fifo_write_request
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_fifo_sync/sys_clk_enable
add wave -noupdate /tb_fifo_sync/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {28744152 ps} 0}
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
WaveRestoreZoom {0 ps} {52432800 ps}
