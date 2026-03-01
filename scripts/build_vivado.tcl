# ===========================================================================
# Vivado TCL Build Script — Acoustic-Optical SoC
# Usage: vivado -mode batch -source scripts/build_vivado.tcl
# ===========================================================================

# -- Project Settings --
set proj_name   "acoustic_optical_soc"
set proj_dir    "./vivado_project"
set part        "xc7a100tcsg324-1"
set top_module  "soc_top"

# -- Create Project --
create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# -- Add HDL Sources --
set hdl_dir "src/hdl"

add_files [list \
    $hdl_dir/cpu/riscv_core.v \
    $hdl_dir/mem/block_ram.v \
    $hdl_dir/audio/pdm_interface.v \
    $hdl_dir/audio/cic_filter.v \
    $hdl_dir/audio/beamformer.v \
    $hdl_dir/dsp/fft_butterfly.v \
    $hdl_dir/dsp/twiddle_rom.v \
    $hdl_dir/dsp/fft_engine.v \
    $hdl_dir/laser/laser_vibrometer.v \
    $hdl_dir/periph/spi_master.v \
    $hdl_dir/periph/uart_tx.v \
    $hdl_dir/periph/uart_rx.v \
    $hdl_dir/periph/gpio.v \
    $hdl_dir/bus/wishbone_interconnect.v \
    $hdl_dir/top/soc_top.v \
]

# -- Add Constraints --
add_files -fileset constrs_1 src/constraints/nexys_a7_100t.xdc

# -- Add Simulation Sources --
set sim_dir "sim"
add_files -fileset sim_1 [list \
    $sim_dir/tb_soc_top.v \
    $sim_dir/tb_riscv_core.v \
    $sim_dir/tb_cic_filter.v \
    $sim_dir/tb_fft_butterfly.v \
    $sim_dir/tb_pdm_interface.v \
    $sim_dir/tb_laser_vibrometer.v \
]
set_property top tb_soc_top [get_filesets sim_1]

# -- Firmware hex file (for Block RAM init) --
# Ensure firmware.hex is built first: cd src/firmware && make hex
add_files -norecurse src/firmware/firmware.hex
set_property used_in_synthesis false [get_files src/firmware/firmware.hex]
set_property used_in_implementation false [get_files src/firmware/firmware.hex]

# -- Set Top Module --
set_property top $top_module [current_fileset]

# -- Run Synthesis --
puts "===== Starting Synthesis ====="
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "===== Synthesis Complete ====="

# -- Check timing after synthesis --
open_run synth_1
report_utilization -file $proj_dir/utilization_synth.rpt
report_timing_summary -file $proj_dir/timing_synth.rpt

# -- Run Implementation (Place & Route) --
puts "===== Starting Implementation ====="
launch_runs impl_1 -jobs 4
wait_on_run impl_1
puts "===== Implementation Complete ====="

# -- Generate Reports --
open_run impl_1
report_utilization -file $proj_dir/utilization_impl.rpt
report_timing_summary -file $proj_dir/timing_impl.rpt
report_power -file $proj_dir/power_impl.rpt

# -- Generate Bitstream --
puts "===== Generating Bitstream ====="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "===== Bitstream Generation Complete ====="

puts "===== BUILD FINISHED ====="
puts "Bitstream: $proj_dir/${proj_name}.runs/impl_1/${top_module}.bit"
