# initialize project
set proj_name [file tail [pwd]]
create_project -part xc7a35tcpg236-1 -force $proj_name ./build

# add source files
set src_files [glob -nocomplain ./src/*.vhd]
add_files -fileset sources_1 $src_files
set_property file_type {VHDL 2008} [get_files $src_files]

# add constraints
add_files -fileset constrs_1 [glob -nocomplain ./constraints/*.xdc]

if {[file isdirectory "./sim"]} {
    set sim_files [glob -nocomplain ./sim/*.vhd]
    if {[llength $sim_files] > 0} {
        add_files -fileset sim_1 $sim_files
        set_property file_type {VHDL 2008} [get_files $sim_files]
    }
}
