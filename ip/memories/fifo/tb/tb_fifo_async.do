onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {clk & reset}
add wave -noupdate /tb_fifo_async/fifo_aclr
add wave -noupdate -divider clk
add wave -noupdate /tb_fifo_async/write_clk
add wave -noupdate /tb_fifo_async/clk_read_normal
add wave -noupdate /tb_fifo_async/clk_read_slow
add wave -noupdate /tb_fifo_async/clk_read_fast
add wave -noupdate -divider {Active CLK}
add wave -noupdate /tb_fifo_async/active_read_clk
add wave -noupdate -divider {DuT - Interface}
add wave -noupdate /tb_fifo_async/read_clk_select
add wave -noupdate /tb_fifo_async/fifo_write_enable
add wave -noupdate -radix unsigned /tb_fifo_async/fifo_write_data
add wave -noupdate /tb_fifo_async/fifo_read_enable
add wave -noupdate -radix unsigned /tb_fifo_async/fifo_read_data
add wave -noupdate /tb_fifo_async/fifo_read_data_valid
add wave -noupdate -divider flags
add wave -noupdate /tb_fifo_async/fifo_empty
add wave -noupdate /tb_fifo_async/fifo_full
add wave -noupdate -radix unsigned /tb_fifo_async/fifo_words_stored
add wave -noupdate -divider {DuT - Internals}
add wave -noupdate -divider FIFO
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/read_address
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/write_address
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/write_pointer_binary
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/read_pointer_binary
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/write_pointer_gray
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/read_pointer_gray
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/write_pointer_gray_sync
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/read_pointer_gray_sync
add wave -noupdate -divider words_stored_calc
add wave -noupdate -radix unsigned /tb_fifo_async/DuT/words_stored_calc/write_ptr_sync
add wave -noupdate -radix decimal /tb_fifo_async/DuT/words_stored_calc/diff
add wave -noupdate -divider {full flag detection}
add wave -noupdate /tb_fifo_async/DuT/full_flag_detect/pointers_msbs_are_different
add wave -noupdate /tb_fifo_async/DuT/full_flag_detect/addresses_msbs_are_different
add wave -noupdate -divider RAM
add wave -noupdate -radix unsigned -childformat {{/tb_fifo_async/DuT/dual_port_ram_inst/ram(31) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(30) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(29) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(28) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(27) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(26) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(25) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(24) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(23) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(22) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(21) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(20) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(19) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(18) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(17) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(16) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(15) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(14) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(13) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(12) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(11) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(10) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(9) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(8) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(7) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(6) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(5) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(4) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(3) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(2) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(1) -radix unsigned} {/tb_fifo_async/DuT/dual_port_ram_inst/ram(0) -radix unsigned}} -subitemconfig {/tb_fifo_async/DuT/dual_port_ram_inst/ram(31) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(30) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(29) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(28) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(27) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(26) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(25) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(24) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(23) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(22) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(21) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(20) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(19) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(18) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(17) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(16) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(15) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(14) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(13) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(12) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(11) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(10) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(9) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(8) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(7) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(6) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(5) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(4) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(3) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(2) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(1) {-height 15 -radix unsigned} /tb_fifo_async/DuT/dual_port_ram_inst/ram(0) {-height 15 -radix unsigned}} /tb_fifo_async/DuT/dual_port_ram_inst/ram
add wave -noupdate -divider {tb - Internal}
add wave -noupdate -radix unsigned /tb_fifo_async/checker/write_count
add wave -noupdate -radix unsigned /tb_fifo_async/checker/read_count
add wave -noupdate -radix unsigned /tb_fifo_async/checker/write_data
add wave -noupdate -radix unsigned /tb_fifo_async/checker/expected_data
add wave -noupdate /tb_fifo_async/clk_read_enable
add wave -noupdate /tb_fifo_async/write_clk_enable
add wave -noupdate /tb_fifo_async/simulation_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6340 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 213
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
WaveRestoreZoom {0 ns} {29023 ns}
