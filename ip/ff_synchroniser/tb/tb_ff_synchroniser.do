onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DuT
add wave -noupdate -divider Interface
add wave -noupdate /tb_ff_synchroniser/source_clk
add wave -noupdate /tb_ff_synchroniser/destination_clk
add wave -noupdate /tb_ff_synchroniser/source_domain
add wave -noupdate /tb_ff_synchroniser/destination_domain_own
add wave -noupdate -divider Internal
add wave -noupdate /tb_ff_synchroniser/Own_Arch_DuT/src_sig
add wave -noupdate -radix binary /tb_ff_synchroniser/Own_Arch_DuT/sync_chain
add wave -noupdate -divider {tb - Internal}
add wave -noupdate /tb_ff_synchroniser/source_clk_enable
add wave -noupdate /tb_ff_synchroniser/destination_clk_enable
add wave -noupdate /tb_ff_synchroniser/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1085020 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 181
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
WaveRestoreZoom {0 ps} {3129 ns}
