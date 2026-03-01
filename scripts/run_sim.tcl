# ===========================================================================
# Vivado TCL Script — Run Simulation
# Usage: vivado -mode batch -source scripts/run_sim.tcl
#        Or: vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_name
# ===========================================================================

# Default testbench
set tb_name "tb_soc_top"
if { $argc > 0 } {
    set tb_name [lindex $argv 0]
}

set proj_dir  "./vivado_project"
set proj_name "acoustic_optical_soc"

# Open project
open_project $proj_dir/$proj_name.xpr

# Set simulation top
set_property top $tb_name [get_filesets sim_1]

# Launch behavioral simulation
puts "===== Running Simulation: $tb_name ====="
launch_simulation -mode behavioral
run 20 ms
puts "===== Simulation Complete ====="

close_sim
close_project
