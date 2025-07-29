onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_rom/sys_clk
add wave -noupdate /tb_rom/sys_rst_n
add wave -noupdate -radix unsigned /tb_rom/address
add wave -noupdate -radix unsigned /tb_rom/q
add wave -noupdate -divider Internal
add wave -noupdate -radix unsigned /tb_rom/DuT/rom_reg_only_for_simulation
add wave -noupdate -radix unsigned /tb_rom/DuT/rom_reg
add wave -noupdate -radix unsigned /tb_rom/DuT/rom_reg
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_rom/sys_clk_enable
add wave -noupdate /tb_rom/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {654440766 ps} 0}
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
WaveRestoreZoom {0 ps} {688165800 ps}
