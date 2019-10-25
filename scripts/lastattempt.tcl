proc dualVth {args} {
	parse_proc_arguments -args $args results
	set savings $results(-savings)
	puts $savings
	#clock clicks -milliseconds
	set start [clock milliseconds]
	# create all global variables
	global leak_start_power 0
	global leak_end_power 0
	global int_start_power 0
	global int_end_power 0
 	global last_opt_list {}	
	# source all procedures
	source ./scripts/getworstpaths.tcl
	source ./scripts/leakage.tcl
	source ./scripts/timing.tcl
	source ./scripts/size_swapping.tcl
	source ./scripts/sizing_fanout.tcl
	source ./scripts/savings_check.tcl
	source ./scripts/cell_swapping.tcl
	# design initialization
	# source ./scripts/pt_analysis.tcl
	# procedure for problem initialization 
	savings_init
	set flag 0
	set_switching_activity -state_condition "default" [get_cell *]
	# leakage power optimization loop
	set N [sizeof_collection [get_cell *]]
	set N [expr $N/15]
#	set slack_list [timing2 $cell_collection]
#	leakage_opt $savings $slack_list $N
	leakage_opt2 $savings $N
	# slack and dyn power optimization loop
	set N 3
	set exit_cnt 0 
	set positive_slack_list {}
	set negative_slack_list {}

	while {[LVT_remaing] > 0 && $exit_cnt < 5 && [slack_finder] < 0} {
		# increase size
		update_timing -full
#		puts "SLACK LOWER THAN ZERO!"
		set cell_list [getworstcells 120]
		set cell_list [listcomp $cell_list $negative_slack_list] 
		if {[llength $cell_list] == 0} {
			#set exit_cnt 30
			set negative_slack_list {}
		}
		set step 0
		while { [llength $cell_list] > 0 && [LVT_remaing] > 0 && [slack_finder] < 0 && $step < 15 } {
			set current_cell [lrange $cell_list 0 0]
			set cell_list [lrange $cell_list 1 end]
			set old_cell [get_attribute [get_lib_cell -of_object [get_cell $current_cell]] base_name]
			if { [upsize $current_cell 3] == 0} { 
				incr exit_cnt
			} else {
				set last_opt_list {}
				#leakage_opt $savings $slack_list $N
				lappend negative_slack_list $current_cell
				leakage_opt2 $savings $N
			}
			if { [leak_savings_check $savings] == 0} {
				#undo last re-sizing 
				#size_swapping $current_cell 0.5
      				size_cell $current_cell $old_cell
				incr exit_cnt
			}
			incr step					
		}	
	}

	# crucial decision: improve timing by increasing dyn power or viceversa
	while {[slack_finder] > 0 && [LVT_remaing] > 0 && $exit_cnt < 3 }  {
#		#set paths_list [timing [get_cell *]]
#		# reduce size
		set flag 1
		update_timing -full
#		puts "SLACK GREATER THAN ZERO!"
		set cell_list [getbestcells]
		set cell_list [listcomp $cell_list $positive_slack_list] 
		if {[llength $cell_list] == 0} {
			set exit_cnt 5
		} 
		set step 0
		while { [llength $cell_list] > 0 && [LVT_remaing] > 0 && [slack_finder] > 0 && $step < 5} {
			set last_opt_list {}
			set current_cell [lrange $cell_list 0 0]
			set cell_list [lrange $cell_list 1 end]
			set old_cell [get_attribute -class lib_cell [get_lib_cell -of_object [get_cell $current_cell]] full_name]			
			puts "current cell: $current_cell, old_cell: $old_cell"
			if { [downsize $current_cell 0.3] == 0} {
				incr exit_cnt
			} else {
				leakage_opt2 $savings $N
				lappend positive_slack_list $current_cell
			}
			if { [leak_savings_check $savings] == 0} {
				#undo last re-sizing 
				#size_swapping $current_cell 1.25
				size_cell $current_cell $old_cell
				incr exit_cnt
			}
			incr step
		}
	}
	
	if {[slack_finder] < 0 && $flag == 1} {
		#undo last swap
#		puts "last_opt_list : $last_opt_list ################# old_cell: $old_cell"
		size_cell $current_cell $old_cell
		HVT2LVT $last_opt_list
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

