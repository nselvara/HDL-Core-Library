global wavefile
set wavefile ${vunit_tb_path}/${vunit_tb_name}.do

# try to source a wave file with the name of the design unit
if { [file exists ${wavefile}] } {
    puts "loading wave from '${wavefile}'."
    do ${wavefile}
} else {
    puts "No Wave file found in the testbench directory. If you save a wave as '${wavefile}', it will be loaded automatically next time."
}
