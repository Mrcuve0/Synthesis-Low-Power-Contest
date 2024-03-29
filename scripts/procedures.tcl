proc LVT2HVT {cell_list} {
	foreach cell $cell_list {
		set cell_ref_name [get_attribute [get_cell $cell] ref_name]
		set cell_base_name [get_attribute [get_cell $cell] base_name]
		regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $cell_ref_name match cell_lib cell_name cell_size
		if {$cell_lib == "L"} {
			set replacements [get_alternative_lib_cells [get_cell $cell]]
			set header "HS65_LH_"
			append header $cell_name 
			append header "X"
			append header $cell_size
			size_cell $cell_base_name $header
		}
	}
	return 1
}


proc HVT2LVT {cell_list} {
	foreach cell $cell_list {
		set cell_ref_name [get_attribute [get_cell $cell] ref_name]
		set cell_base_name [get_attribute [get_cell $cell] base_name]
		regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $cell_ref_name match cell_lib cell_name cell_size
		if {$cell_lib == "H"} {
			set replacements [get_alternative_lib_cells [get_cell $cell]]
			set header "HS65_LL_"
			append header $cell_name 
			append header "X"
			append header $cell_size
			size_cell $cell_base_name $header
		}
	}
	return 1
}



proc upsize {cell_list percentage} {
        # initial input check
        if {[llength $cell_list] == 0} {
                puts "Empty cell list"
                return 0
        }

        set match 0
        set cell_lib {}
        set repl_lib {}
        set cell_size 0
        set repl_size 0
        set swap_cell 0

        foreach cell $cell_list {
                set cell_ref_name [get_attribute [get_cell $cell] ref_name]
                set base_name [get_attribute [get_cell $cell] base_name]
                regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $cell_ref_name match cell_lib cell_name cell_size
                #puts "size of original cell is : $cell_size"
                set replacements [get_alternative_lib_cells $cell]

                set candidates {}
                foreach_in_collection i $replacements {
                        set repl_ref_name [get_attribute -class lib_cell $i base_name]
                        regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $repl_ref_name match repl_lib repl_name repl_size
                        if { $cell_lib == $repl_lib && $cell_name == $repl_name && $repl_size >= $cell_size} {
                                set temp {}
                                lappend temp $repl_ref_name
                                lappend temp $repl_size
                                lappend candidates $temp
                        }
                }
                if {[llength candidates] == 0} {
                        return 0
                }
                set threshold [expr $cell_size*$percentage+1]
                set candidates [lsort -real -index 1 -increasing $candidates]
                #set swap_cell [lindex $candidates end 0]
                foreach repl $candidates {
                        if { [lindex $repl 1] <= $threshold} {
                                set swap_cell [lindex $repl 0]
                        }
                }
                if {$swap_cell == 0} {
                        return 0
                }
                size_cell $base_name $swap_cell
        }
        return 1
}
proc downsize {cell_list percentage} {
        # initial input check
        if {[llength $cell_list] == 0} {
                puts "Empty cell list"
                return 0
        }

        set match 0
        set cell_lib {}
        set repl_lib {}
        set cell_size 0
        set repl_size 0
        set swap_cell 0

        foreach cell $cell_list {
                set cell_ref_name [get_attribute -class cell $cell ref_name]
                set base_name [get_attribute -class cell $cell base_name]
                regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $cell_ref_name match cell_lib cell_name cell_size
               	set replacements [get_alternative_lib_cells $cell]
                set candidates {}
                foreach_in_collection i $replacements {
                        set repl_ref_name [get_attribute -class lib_cell $i base_name]
                        regexp {HS65\_L([A-Z]+)\_([A-Z 0-9]+)X([0-9]+)} $repl_ref_name match repl_lib repl_name repl_size
                        if { $cell_lib == $repl_lib && $cell_name == $repl_name && $repl_size <= $cell_size} {
                                set temp {}
                                lappend temp $repl_ref_name
                                lappend temp $repl_size
                                lappend candidates $temp
                        }
                }
                if {[llength candidates] == 0} {
                        return 0
                }
                set threshold [expr $cell_size*$percentage]
                set candidates [lsort -integer -index 1 -increasing $candidates]
              	foreach repl $candidates {
                        if { [lindex $repl 1] <= $threshold+1} {
                                set swap_cell [lindex $repl 0]
                        }
                }
		if {$swap_cell == 0} {
			return 0
		}
                size_cell $base_name $swap_cell
        }
        return 1
}

proc listcomp {a b} {
        set diff {}
        foreach i $a {
                if {[lsearch -exact $b $i]==-1} {
                        lappend diff $i
                }
        }
        return $diff
}

proc getbestcells {} {

        set paths [get_timing_paths -nworst 150 -max_paths 150 -slack_greater_than 0]
        set worst_cell_list {}
        foreach_in_collection timingPath $paths {
                set listTimingPoints [get_attribute $timingPath points]
                foreach_in_collection timingPoint $listTimingPoints {
                        set pin_name [get_attribute [get_attribute $timingPoint object] full_name]
                        # neglect the port, consider only pins
                        if { [regexp {[A-Z a-z 0-9]+\/[A-Z a-z 0-9]+} $pin_name] } {
                                set cell_name [get_attribute [get_attribute [get_pin $pin_name] cell] base_name]
                                lappend worst_cell_list $cell_name
                        }
                }
        }
        # remove double occurrences of the same cell
        set worst_cell_list [lsort -unique $worst_cell_list]
        set all_cell_list [get_attribute [get_cell *] base_name]
        set all_cell_list [lsort  $all_cell_list]
        set cell_list [listcomp $all_cell_list $worst_cell_list]
        puts "#################### Available cell for SLack > 0 optimization: wcl [llength $worst_cell_list], cl [llength $cell_list]  ###################################"
        foreach cell $cell_list {
                set out_pin [get_pin -filter {direction == out} -of_object [get_cell $cell]]
                set out_pin_coll [filter_collection [get_attribute [all_connected $out_pin] leaf_loads] {object_class==pin}]

                #set in_pin [get_pin -filter {direction == in} -of_object [get_cell $cell]]
                #set in_pin_coll [filter_collection [get_attribute [all_connected $in_pin] leaf_loads] {object_class==pin}]

                #puts [get_attribute $out_pin_coll full_name]           
                #puts [get_attribute $in_pin_coll full_name]

                #set fanout [sizeof_collection $out_pin_coll]
                set res1 0
                foreach_in_collection pin $out_pin_coll {
                        set prob [get_attribute $pin static_probability]
                        set sw [expr 2*$prob*(1-$prob)]
                        set cap [get_attribute [get_lib_pins -of_object $pin] pin_capacitance]
                        set res1 [expr $res1 + $cap*$sw]
                }
                #set res2 0
                #foreach_in_collection pin $in_pin_coll {
                #       set prob [get_attribute $pin static_probability]
                #       set sw [expr 2*$prob*(1-$prob)]
                #       #set cap [get_attribute [get_lib_pins -of_object $pin] pin_capacitance]
                #       set res2 [expr $res2 + $sw]
                #}
                set temp {}
                lappend temp $cell
                lappend temp $res1
                #lappend temp $res2
                lappend cell_list_ordered $temp
        }

        set cell_list_ordered [lsort -real -index 1 -increasing $cell_list_ordered]
        set cell_list_filtered {}
        foreach i $cell_list_ordered {
                lappend cell_list_filtered [lindex $i 0]
        }
        return $cell_list_filtered
}



proc getworstcells {number_of_paths} {
        # Get the list of timing paths retrieved
        set listTimingPaths [get_timing_paths -nworst $number_of_paths -max_paths $number_of_paths -slack_lesser_than 0]

        # Loops through the list of timing paths
        set cell_list {}
        foreach_in_collection timingPath $listTimingPaths {

                set listTimingPoints [get_attribute $timingPath points]
                #set current_path {}
                # Loops through the list of timing points and sets a list of cells
                # Assumption: each timing point corresponds to a cell, we need only cells objects
                foreach_in_collection timingPoint $listTimingPoints {
                        #set out_pin [get_pin -filter {direction == out}  [get_attribute $timingPoint object] ]
                        #set cell_name [get_attribute [get_attribute $out_pin cell] full_name]
                        set pin_name [get_attribute [get_attribute $timingPoint object] full_name]
                        if { [regexp {[A-Z a-z 0-9]+\/[A-Z a-z 0-9]+} $pin_name] } {
                                set cell_name [get_attribute [get_attribute [get_pin $pin_name] cell] full_name]
                                lappend cell_list $cell_name
                        }
                }
        }
        set cell_list [lsort -unique $cell_list]
        set cell_list_ordered {}
        foreach cell $cell_list {
                set pins [get_pin -filter {direction == in} -of_object [get_cell $cell]]
                set res 0
                foreach_in_collection pin $pins {
                        #set tc [get_attribute $pin toggle_rate]
                        set prob [get_attribute $pin static_probability]
                        set sw [expr 2*$prob*(1-$prob)]
                        set cap [get_attribute [get_lib_pins -of_object $pin] pin_capacitance]
                        set res [expr $res + $cap*$sw]
                }
                set temp {}
                lappend temp $cell
                lappend temp $res
                lappend cell_list_ordered $temp
        }

        set cell_list_ordered [lsort -real -index 1 -decreasing $cell_list_ordered]
        set cell_list_filtered {}
        foreach i $cell_list_ordered {
                lappend cell_list_filtered [lindex $i 0]
        }
        return $cell_list_filtered
}

proc LVT_remaing {} {
        set cnt 0
        foreach_in_collection cell [get_cell *] {
                if {[get_attribute [get_libs -of_objects [get_lib_cell -of_object $cell]] default_threshold_voltage_group] == "LVT"} {
                        incr cnt
                }
        }
        set tot [sizeof_collection [get_cell *]]
        set cnt [expr $cnt - $tot/4]
        return $cnt
}

proc leakage_opt2 {savings N leak_start_power} {
        set slack_list {}
        foreach_in_collection cell [get_cell *] {
                if {[get_attribute [get_libs -of_object [get_lib_cell -of_object $cell]] default_threshold_voltage_group] == "LVT"} {
                        set pins [get_pin -filter {direction == out} -of_object $cell]
                        set cell_name [get_attribute $cell full_name]
                        foreach_in_collection pin $pins {
                                set slack [get_attribute $pin max_slack]
                                set temp {}
                                lappend temp $cell_name
                                lappend temp $slack
                                lappend slack_list $temp
                        }
                }
        }
        set slack_list [ lsort -real -decreasing -index 1 $slack_list]
        set slack_list_ordered {}
        foreach i $slack_list {
                lappend slack_list_ordered [lindex $i 0]
        }

        while { [leak_savings_check $savings $leak_start_power] == 0 && [LVT_remaing] > 0 && [llength $slack_list_ordered] > 0} {
                set cell_list [lrange $slack_list_ordered 0 $N]
                set slack_list_ordered [lrange $slack_list_ordered [expr $N+1] end]
                LVT2HVT $cell_list
        }
        return
}

proc leak_savings_check {saving leak_start_power} {
        report_power > "./saved/aes_cipher_top/post_synthesis_sim/my_report_power.txt"
        set fid [open "./saved/aes_cipher_top/post_synthesis_sim/my_report_power.txt" "r"]
        set mantissa 0
        set esponente 0
        while { [gets $fid line] >= 0} {
                regexp {^\s+Cell\s+Leakage\s+Power\s+\=\s+([0-9]*\.[0-9]+)e([-+]?[0-9]+)} $line match mantissa esponente
        }
        set esponente [regsub "0" $esponente ""]
        set leak_end_power [expr $mantissa*pow(10,$esponente)]
        close $fid

	set obj [ expr $leak_start_power*(1-$saving) ]
        if {$leak_end_power <= $obj} {
                return 1
        } else {
                return 0
        }
}

proc savings_init {} {
      #  global leak_start_power
       # global int_start_power
        report_power > "./saved/aes_cipher_top/post_synthesis_sim/my_report_power.txt"
        set fid [open "./saved/aes_cipher_top/post_synthesis_sim/my_report_power.txt" "r"]
        set mantissa1 0
        set esponente1 0
       # set mantissa2 0
       # set esponente2 0
        while { [gets $fid line] >= 0} {
                regexp {^\s+Cell\s+Leakage\s+Power\s+\=\s+([0-9]*\.[0-9]+)e([-+]?[0-9]+)} $line match mantissa1 esponente1
        #        regexp {^\s+Cell\s+Internal\s+Power\s+\=\s+([0-9]*\.[0-9]+)e([-+]?[0-9]+)} $line match mantissa2 esponente2
        }
        set esponente1 [regsub "0" $esponente1 ""]
       # set esponente2 [regsub "0" $esponente2 ""]
        set leak_start_power [expr $mantissa1*pow(10,$esponente1)]
       # set int_start_power [expr $mantissa2*pow(10,$esponente2)]
        close $fid
	return $leak_start_power
}

proc slack_finder {} {
        #global initial_slack
        report_timing > "./saved/aes_cipher_top/post_synthesis_sim/my_report_timing.txt"
        set fid [open "./saved/aes_cipher_top/post_synthesis_sim/my_report_timing.txt" "r"]
        set current_slack 0
        while { [gets $fid line] >= 0} {
                regexp {^\s+slack\s+\([A-Z a-z]+\)\s+([-+]?[0-9]*\.[0-9]+)} $line match current_slack
        }
        close $fid

        return $current_slack
}
