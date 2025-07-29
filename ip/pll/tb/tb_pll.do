onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_pll/in_clk
add wave -noupdate /tb_pll/out_clk_0
add wave -noupdate /tb_pll/out_clk_1
add wave -noupdate -divider Internal
add wave -noupdate -radix unsigned /tb_pll/out_clk_0_edges
add wave -noupdate -radix unsigned /tb_pll/out_clk_1_edges
add wave -noupdate /tb_pll/reset_out_clk_0
add wave -noupdate /tb_pll/reset_out_clk_1
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_pll/in_clk_enable
add wave -noupdate /tb_pll/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {26869361 ps} 0}
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
WaveRestoreZoom {0 ps} {33921300 ps}
