# Run with quartus_sta -t scripts/report_worst.tcl after the final fitter.
set root [file normalize [file join [file dirname [info script]] ..]]
cd [file join $root src projects]
project_open asterix_pocket -revision asterix_pocket
foreach model {slow fast} {
    create_timing_netlist -model $model
    read_sdc
    # Record the actual fitted endpoints, including any fitter-created aliases.
    # Source-level enable proofs require an independent review of these names
    # against the fitter's retiming/duplication optimization table.
    set endpoints [open [file join output_files ${model}_multicycle_endpoints.txt] w]
    foreach {label collection} [list FM_PHASE_SOURCES $FM_PHASE_SOURCES \
            FM_PHASE_TARGETS $FM_PHASE_TARGETS \
            Z80_DECODE_SOURCES $Z80_DECODE_SOURCES \
            Z80_GATED_TARGETS $Z80_GATED_TARGETS \
            FX_IR_SOURCE $FX_IR_SOURCE FX_NANO_TARGET $FX_NANO_TARGET] {
        puts $endpoints "$label: [get_collection_size $collection]"
        foreach_in_collection node $collection {
            puts $endpoints [get_node_info -name $node]
        }
    }
    close $endpoints
    foreach_in_collection op [get_available_operating_conditions] {
        set label [get_operating_conditions_info $op -display_name]
        if {![string match -nocase ${model}* $label]} {continue}
        set_operating_conditions $op
        update_timing_netlist
        set stem [string map {" " "_" "/" "_"} $label]
        foreach check {setup hold recovery removal} {
            report_timing -$check -npaths 30 -detail full_path \
                -file [file join output_files ${stem}_${check}_paths.txt]
        }
        # One worst path per destination distinguishes the complete set of
        # failing register groups from repeated paths into the same endpoint.
        report_timing -setup -npaths 3000 -nworst 1 -detail summary \
            -file [file join output_files ${stem}_setup_distinct_endpoints.txt]
        report_timing -setup -npaths 10 -detail full_path -to_clock dram_clk \
            -file [file join output_files ${stem}_dram_setup_paths.txt]
        report_timing -hold -npaths 10 -detail full_path -from_clock dram_clk \
            -file [file join output_files ${stem}_dram_hold_paths.txt]
        report_timing -setup -npaths 10 -detail full_path -from_clock dram_clk \
            -file [file join output_files ${stem}_dram_input_setup_paths.txt]
        set sys_clock {ic|core_pll|core_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
        set pixel_clock {ic|core_pll|core_pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}
        report_timing -setup -npaths 10 -detail full_path -from_clock $sys_clock -to_clock $pixel_clock \
            -file [file join output_files ${stem}_system_to_pixel_paths.txt]
        report_timing -hold -npaths 10 -detail full_path -from_clock $pixel_clock -to_clock $sys_clock \
            -file [file join output_files ${stem}_pixel_to_system_hold_paths.txt]
        set audio_clock {ic|pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
        set audio_serial_clock {ic|pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}
        report_timing -setup -npaths 10 -detail full_path -from_clock $audio_clock -to_clock $audio_serial_clock \
            -file [file join output_files ${stem}_audio_to_serial_paths.txt]
        report_clock_transfers -file [file join output_files ${stem}_clock_transfers.txt]
    }
    report_clocks -file output_files/clocks.txt
    report_sdc -file output_files/sdc_applied.txt
    delete_timing_netlist
}
project_close -dont_export_assignments
