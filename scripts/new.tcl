proc dualVth {args} {
	parse_proc_arguments -args $args results
	set savings $results(-savings)
	puts $savings
	# estimate latency 
	set start [clock milliseconds]

	# source all procedures
	source ./scripts/procedures.tcl

	# design initialization
	# source ./scripts/pt_analysis.tcl

	# procedure for problem initialization 
	set leak_start_power [savings_init]

	# downsize the entire design. 
	foreach_in_collection cell [get_cell *] {
		downsize [get_attribute $cell base_name] 0.5
	}
	# leakage power optimization loop
	set N [sizeof_collection [get_cell *]]
	set N [expr $N/15]
	leakage_opt2 $savings $N $leak_start_power
	set N 3
	set exit_cnt 0 
	set negative_slack_list {}
	while {[LVT_remaing] > 0 && $exit_cnt < 25 && [slack_finder] < 0} {
		update_timing -full
		set cell_list [getworstcells 200]
		set cell_list [listcomp $cell_list $negative_slack_list] 
		if {[llength $cell_list] == 0} {
			set negative_slack_list {}
		}
		set step 0
		while { [llength $cell_list] > 0 && [LVT_remaing] > 0 && [slack_finder] < 0 && $step < 25 } {
			set current_cell [lrange $cell_list 0 0]
			set cell_list [lrange $cell_list 1 end]
			set old_cell [get_attribute [get_lib_cell -of_object [get_cell $current_cell]] base_name]
			if { [upsize $current_cell 1.8] == 0} { 
				incr exit_cnt
			} else {
				lappend negative_slack_list $current_cell
				leakage_opt2 $savings $N $leak_start_power
			}
			if { [leak_savings_check $savings $leak_start_power] == 0} {
				#undo last re-sizing 
      				size_cell $current_cell $old_cell
				incr exit_cnt
			}
			incr step					
		}	
	}
	set end [clock milliseconds]
	puts [expr $end -$start] 
	report_timing
	report_power
	return
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" value float required}
}

