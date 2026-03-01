# ===========================================================================
# Vivado TCL Script — Program FPGA
# Usage: vivado -mode batch -source scripts/program_fpga.tcl
# ===========================================================================

set bitstream "vivado_project/acoustic_optical_soc.runs/impl_1/soc_top.bit"

# Open hardware manager
open_hw_manager
connect_hw_server -allow_non_jtag

# Auto-detect target (Nexys A7)
open_hw_target

# Get the device
set device [lindex [get_hw_devices] 0]
current_hw_device $device

# Set bitstream
set_property PROGRAM.FILE $bitstream $device

# Program
puts "===== Programming FPGA ====="
program_hw_devices $device
puts "===== FPGA Programmed Successfully ====="

# Close
close_hw_target
disconnect_hw_server
close_hw_manager
