set proj_name [file tail [pwd]]
open_project ./build/$proj_name.xpr

# figure out dependencies
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs -jobs 4 synth_1
wait_on_run synth_1

launch_runs -jobs 4 impl_1
wait_on_run impl_1

open_run impl_1
write_bitstream -force ./build/$proj_name.runs/impl_1/WRAPPER.bit

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}
