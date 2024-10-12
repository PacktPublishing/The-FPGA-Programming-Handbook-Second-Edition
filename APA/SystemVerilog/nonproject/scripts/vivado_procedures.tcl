proc read_files {file_list} {
    foreach file $file_list {
        set extension [file extension $file]
        if {$extension == ".sv"} {
            read_verilog -sv $file
        } elseif {$extension == ".v"} {
            read_verilog $file
        } elseif {$extension == ".vhd"} {
            read_vhdl -vhdl2008 $file
        } elseif {$extension == ".xci"} {
            read_ip $file
        }
    }
    update_compile_order
}

proc synthesis {} {
    global ip_dcps
    global BEST_CP
    global top_module

    set SYNTH_ARGS ""

    # Read design files
    source "overrides.inc"

    # Read high level constraints
    read_xdc -unmanaged ../../../../APA/xdc/vga.xdc

    # make latch inferrence an error
    set_msg_config -id {[Synth 8-327]} -new_severity ERROR

    # Synthesis (timing driven)
    # if You want to target a part, use the following command
    set_property PART $fpga_part [current_project]
    # to use a BSP
    #set_property board_part digilentinc.com:nexys-a7-100t:part0:1.2 [current_project]

    # synthesis related settings
    append SYNTH_ARGS " " -flatten_hierarchy " " rebuilt " "
    append SYNTH_ARGS " " -gated_clock_conversion " " off " "
    append SYNTH_ARGS " " -bufg " {" 12 "} "
    append SYNTH_ARGS " " -fanout_limit " {" 10000 "} "
    append SYNTH_ARGS " " -directive " " Default " "
    append SYNTH_ARGS " " -fsm_extraction " " auto " "
    #append SYNTH_ARGS " " -keep_equivalent_registers " "
    append SYNTH_ARGS " " -resource_sharing " " auto " "
    append SYNTH_ARGS " " -control_set_opt_threshold " " auto " "
    #append SYNTH_ARGS " " -no_lc " "
    #append SYNTH_ARGS " " -shreg_min_size " {" 3 "} "
    append SYNTH_ARGS " " -shreg_min_size " {" 5 "} "
    append SYNTH_ARGS " " -max_bram " {" -1 "} "
    append SYNTH_ARGS " " -max_dsp " {" -1 "} "
    append SYNTH_ARGS " " -cascade_dsp " " auto " "
    append SYNTH_ARGS " " -verbose

    eval "synth_design $SYNTH_ARGS -top $top_module -part $fpga_part"

    set BEST_CP post_synth
    write_checkpoint -force $BEST_CP
    report_timing -sort_by group -max_paths 5 -path_type summary    -file post_synth_timing.rpt
    report_timing -nworst 1 -path_type full                         -file post_synth_worst_timing_path.rpt
    report_utilization                                              -file post_synth_util.rpt
    report_compile_order -constraints                               -file post_synth_compile_order_constr.rpt
    report_clocks                                                   -file post_synth_clocks.rpt

    # Apply all remaining constraints
    #This is handled after this proc returns, i.e. as part of implementation step
    return 0
}
# Pre-Implementation
proc pre_implement {} {
    global ip_dcps

    # Apply all remaining constraints
    opt_design -directive ExploreWithRemap
    return 1
}

proc implement {{ila_insert 0}} {
    global init_data
    global POST_PLACE_PHYS_OPT_LOOPS
    global POST_ROUTE_PHYS_OPT_LOOPS
    global IGNORE_TNS
    global timing_result
    global WNS
    global BEST_CP
    global CHECKPOINT_SAVED
    global PLACE_DIRECTIVE
    global ROUTE_DIRECTIVE
    global TOP_MODULE

    if {$ila_insert == 1} {
        stop_gui
        implement_debug_core
    }

    write_debug_probes ila_debug.ltx
    set BEST_CP post_opt
    write_checkpoint -force $BEST_CP
    report_utilization                -file post_opt_util.rpt
    report_compile_order -constraints -file post_opt_compile_order_constr.rpt
    report_clocks                     -file post_opt_clocks.rpt

    place_design -directive $PLACE_DIRECTIVE

    set BEST_CP post_place
    write_checkpoint -force $BEST_CP
    report_utilization                -file post_place_util.rpt

    # Load clock constraints that aren't available until the PLLS are generated
    if {[file exists "../../../../APA/xdc/design_post_place.xdc"]} {
        read_xdc -unmanaged "../../../../APA/xdc/design_post_place.xdc"
    }

    # Post Place PhysOpt Looping -
    # Post placement physopt is rentrant and converges on a solution. It can be made to run in a loop
    #
    if {$WNS < 0.000} {

        for {set i 0} {$i < $POST_PLACE_PHYS_OPT_LOOPS} {incr i} {
            set CHECKPOINT_SAVED 0

            puts "============== Beginning phys_opt_design (post-place) loop $i"

            place_design -post_place_opt
            if {[update_results "Physopt Loop $i: Post Place Opt" post_place_opt "routing"]} {
                break
            }

            phys_opt_design -slr_crossing_opt
            if {[update_results "Physopt Loop $i: SLR crossing optimization" post_place_physopt "routing"]} {
                break
            }

            phys_opt_design -directive AggressiveExplore
            if {[update_results "Physopt Loop $i: AggressiveExplore" post_place_physopt "routing"]} {
                break
            }

            phys_opt_design -directive AggressiveFanoutOpt
            if {[update_results "Physopt Loop $i: AggressiveFanoutOpt" post_place_physopt "routing"]} {
                break
            }

            phys_opt_design -directive AlternateFlowWithRetiming
            if {[update_results "Physopt Loop $i: AlternateFlowWithRetiming" post_place_physopt "routing"]} {
                break
            }

            if {$CHECKPOINT_SAVED == 0} {
                puts "Physopt Loop $i resulted in no saved dcp, i.e. no improvement in timing. Aborting further trials, and continuing with routing"
                break
            }

        }
    }

    route_design -directive $ROUTE_DIRECTIVE
    record_tool_output "route_design" "keep"

    set BEST_CP post_route
    write_checkpoint -force $BEST_CP
    record_tool_output "route_design (post)" "-" 0

    # Post Route PhysOpt Looping
    if {$WNS < 0.000} {
        for {set i 0} {$i < $POST_ROUTE_PHYS_OPT_LOOPS} {incr i} {
            set CHECKPOINT_SAVED 0

            puts "============== Beginning phys_opt_design (post-route) loop $i"

            phys_opt_design -placement_opt -routing_opt -rewire -critical_cell_opt -slr_crossing_opt -clock_opt -retime
            if {[update_results "Physopt Loop $i: Post Route Opt" post_route_physopt "bitstream generation" 1]} {
                break
            }
        }
    }

    # Final touches
    if {[file exists "post_route_final.dcp"]} {
        file delete post_route_final.dcp
    }
    file link post_route_final.dcp $BEST_CP.dcp

    report_timing_summary                                           -file post_route_timing_summary.rpt
    report_timing -sort_by group -max_paths 100 -path_type summary  -file post_route_timing.rpt
    report_timing -nworst 1 -path_type full                         -file post_route_worst_timing_path.rpt
    report_utilization                                              -file post_route_util.rpt
    report_exceptions -summary                                      -file post_route_ignored_constr.rpt
    report_exceptions -ignored                                      -file post_route_ignored_constr.rpt -append
    report_exceptions -ignored_objects                              -file post_route_ignored_constr.rpt -append

    # General output
    report_drc                                                      -file post_route_drc.rpt
    write_verilog -force post_route.${TOP_MODULE}.v
    write_xdc -no_fixed_only -force post_route.${TOP_MODULE}.xdc
    record_tool_output "phys_opt_design route final (post)" "-" 0

    # Generate bitstream
    write_bitstream -file ${TOP_MODULE}
    record_tool_output "write_bitstream" "-" 0

    # Report data for FPGA initialization after loading of the bitstream onto the FPGA
    record_tool_output "Analyze Timing and Determine Core Clk Freq" "-" 0

    # Print out the results of all loops
    print_timing_info
}

proc check_invalid_xdc {fname} {
    # Write XDC containing invalid constraints
    # Return non-0 if at least one non-comment and non-blank line exists in that file
    write_xdc -constraints invalid $fname
    if {[file exists $fname]} {
        set fptr [open $fname r]
        set lines [read -nonewline $fptr]
        close $fptr
        foreach line [split $lines "\n"] {
            if {[regexp {^[^#].*} $line match]} {
                puts "ERROR: Invalid constraints are found, saved in '$fname'"
                return 1
            }
        }
    }
    return 0
}

proc get_timing_info { {report {}} } {
    if {$report == {}} {
        set report [split [report_timing_summary -no_detailed_paths -no_check_timing -no_header -return_string] \n]
    } else {
        set report [split $report \n]
    }

    foreach {wns tns tnsFailingEp tnsTotalEp whs ths thsFailingEp thsTotalEp wpws tpws tpwsFailingEp tpwsTotalEp} [list {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A} {N/A}] {
        break
    }
    if {[set i [lsearch -regexp $report {Design Timing Summary}]] != -1} {
        foreach {wns tns tnsFailingEp tnsTotalEp whs ths thsFailingEp thsTotalEp wpws tpws tpwsFailingEp tpwsTotalEp} [regexp -inline -all -- {\S+} [lindex $report [expr $i + 6]]] {
            break
        }
    }
    set formatStr {%15s|%15s|%15s|%30s|%30s}
    puts "\n\n"
    puts [format $formatStr "Setup" "WNS = $wns" "TNS = $tns" "Failing Endpoints = $tnsFailingEp" "Total Endpoints = $tnsTotalEp"]
    puts [format $formatStr " Hold" "WHS = $whs" "THS = $ths" "Failing Endpoints = $thsFailingEp" "Total Endpoints = $thsTotalEp"]
    puts "\n\n"
    return [list $wns $tns $whs $tnsFailingEp $tnsTotalEp]
}

proc record_tool_output {step {status ""} {timing_info 1}} {
    global CUR_TIME
    global timing_result
    global WNS_PREV
    global TNS_PREV
    global WNS
    global TNS

    set time_elapsed [expr [clock seconds] - $CUR_TIME]
    set CUR_TIME [clock seconds]

    if {$timing_info == 1} {
        # local_timing contains: [0]:WNS [1]:TNS [2]:WHS [3]:TNSFailingEP [4]:TNSTotalEP
        set local_timing [get_timing_info]

        set WNS_PREV $WNS
        set TNS_PREV $TNS
        set WNS [lindex $local_timing 0]
        set TNS [lindex $local_timing 1]
    } else {
        set local_timing [list "-" "-" "-" "-" "-"]
    }

    # insert the run name into local timing
    set local_timing [linsert $local_timing 0 $step $time_elapsed]

    # insert status info into local timing, if provided
    if {$status != ""} {
        lappend timing_result [lappend local_timing $status]
    }

    return $local_timing
}

proc update_results {step dcp next_step {notify_if_dropping 0}} {
    global TERM_FILE
    global IGNORE_TNS
    global timing_result
    global WNS_PREV
    global TNS_PREV
    global WNS
    global TNS
    global BEST_CP
    global CHECKPOINT_SAVED

    set local_timing [record_tool_output $step]

    if {($TNS > $TNS_PREV && $WNS == $WNS_PREV && $IGNORE_TNS == 0) || ($WNS > $WNS_PREV)} {
        lappend timing_result [lappend local_timing "keep"]
        set BEST_CP $dcp
        write_checkpoint -force $BEST_CP    ; # No need to specify extension if it is .dcp, i.e. only name is sufficient
        record_tool_output "$step (post)" "-" 0
        incr CHECKPOINT_SAVED
        if {$WNS >= 0.000} {
            puts "Design meets timing, beginning $next_step phase"
            return 1
        }
    } else {
        # Worse or same TNS and unchanged WNS, OR worse WNS than last run, so bail
        lappend timing_result [lappend local_timing "drop"]
        puts "$step did not improve timing. So, dropping it, i.e. not saving output, and reverting to the previous best checkpoint."
        close_design
        open_checkpoint $BEST_CP.dcp        ; # Must specify full file name, including the extension
        record_tool_output "$step (post)" "-" 0
        set WNS $WNS_PREV
        set TNS $TNS_PREV
        if {$notify_if_dropping > 0} {
            return 2
        }
    }

    if {[file exists $TERM_FILE]} {
        puts "Detected presence of file '$TERM_FILE'. Terminating trials in a loop"
        return 3
    }

    return 0
}

proc print_timing_info {} {
    global timing_result

    set formatStr {%-50s %10s %10s %10s %10s %15s %10s %20s}

    puts "\n\nFinal Timing Summary from all runs:\n"
    puts "=============================================================================================================================================="
    puts [format $formatStr "Implementation Step" "Time" "WNS" "TNS" "WHS" "TNS total EPs" "keep/drop" "Failing Endpoint"]
    # Timing results has the format 0:step 1:Time 2:WNS 3:TNS 4:WHS 5:TNSFailingEP 6:TNSTotal 7:keep/drop
    foreach step $timing_result {
        set impl   [lindex  $step 0]
        set timex  [lindex  $step 1]
        set wns    [lindex  $step 2]
        set tns    [lindex  $step 3]
        set whs    [lindex  $step 4]
        set tnsep  [lindex  $step 5]
        set tnstot [lindex  $step 6]
        set status [lindex  $step 7]    ; # keep/drop
        puts [format $formatStr $impl [clock format $timex -format %T -timezone UTC] $wns $tns $whs $tnstot $status $tnsep]
    }
    puts "=============================================================================================================================================="
    puts ""
}
