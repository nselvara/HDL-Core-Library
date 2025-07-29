onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_dual_port_ram/sys_clk
add wave -noupdate /tb_dual_port_ram/sys_rst_n
add wave -noupdate -radix unsigned /tb_dual_port_ram/write_address
add wave -noupdate -radix unsigned /tb_dual_port_ram/read_address
add wave -noupdate /tb_dual_port_ram/en
add wave -noupdate /tb_dual_port_ram/write_enable
add wave -noupdate /tb_dual_port_ram/read_enable
add wave -noupdate -radix unsigned /tb_dual_port_ram/data_in
add wave -noupdate -radix unsigned /tb_dual_port_ram/data_out
add wave -noupdate -divider Internal
add wave -noupdate -radix unsigned /tb_dual_port_ram/DuT/mem_operation_proc/ram_reg
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_dual_port_ram/sys_clk_enable
add wave -noupdate /tb_dual_port_ram/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1538264 ps} 0}
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {11167800 ps}
