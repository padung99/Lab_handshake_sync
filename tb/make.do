set path_to_library C:/intelFPGA_lite/18.1/quartus/eda/sim_lib
vlib work

set source_file {
  "../rtl/handshake_sync.sv"
  "handshake_sync_tb.sv"
}

vlog $path_to_library/altera_mf.v

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*
add wave -r *
add wave "sim:/handshake_sync_tb/dut1/mem"
#add wave -group dut1 /fifo_dc_tb/dut1/*
#add wave -group dut2 /fifo_dc_tb/dut2/*

view -undock wave
run -all