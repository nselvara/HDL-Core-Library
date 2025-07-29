onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_reset_on_startup/clk
add wave -noupdate -expand /tb_reset_on_startup/rst_in
add wave -noupdate -expand /tb_reset_on_startup/rst_out
add wave -noupdate -divider Internal
add wave -noupdate /tb_reset_on_startup/gen_duts(0)/DuT/reset_on_startup
add wave -noupdate /tb_reset_on_startup/gen_duts(0)/DuT/rst_delayed
add wave -noupdate -radix unsigned /tb_reset_on_startup/gen_duts(0)/DuT/reset_controller/startup_counter
add wave -noupdate /tb_reset_on_startup/gen_duts(1)/DuT/reset_on_startup
add wave -noupdate /tb_reset_on_startup/gen_duts(1)/DuT/rst_delayed
add wave -noupdate -radix unsigned /tb_reset_on_startup/gen_duts(1)/DuT/reset_controller/startup_counter
add wave -noupdate -divider {tb - Interal}
add wave -noupdate /tb_reset_on_startup/clk_enable
add wave -noupdate /tb_reset_on_startup/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {315544 ps} 0}
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
WaveRestoreZoom {0 ps} {331800 ps}
