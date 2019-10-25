# Script
# INPUT: #Of paths to be analyzed, minimum Slack Value, maximum Slack Value
# RETURN: all the cells that compose each critical path

set numWorstPaths 25
set maxPaths 25
set minSlack 0.6
set maxSlack 1.0

puts "numWorstPaths: "
puts $numWorstPaths
puts "minSlack: " 
puts $minSlack
puts "maxSlack: " 
puts $maxSlack

proc getCellsFromBestTimingPaths {numWorstPaths maxPaths minSlack maxSlack} {

	# Get the list of timing paths retrieved
	set listTimingPaths [get_timing_paths -nworst $numWorstPaths -max_paths $maxPaths -slack_greater_than $minSlack -slack_lesser_than $maxSlack]
	set index 0
	
	# Loops through the list of timing paths
	foreach_in_collection timingPath $listTimingPaths {
		
		puts "\n\nNew timing path..."
		set listTimingPoints [get_attribute $timingPath points]
	
		# Loops through the list of timing points and sets a list of cells
		# Assumption: each timing point corresponds to a cell, we need only cells objects
		foreach_in_collection timingPoint $listTimingPoints {
			set pin [get_attribute $timingPoint object]
			set cell [get_attribute $pin cell]
			puts [get_attribute $cell full_name]
			set listCells ""
			lappend listCells $cell
			#puts $listCells
		}

		set listCellsPerPath ""
		lappend listCellsPerPath [ linsert listTimingPaths $index [lindex $listCells $index] ]	
		set index [expr $index + 1]
	}
	puts $listCellsPerPath
	puts [lindex $listCellsPerPath 0]
	puts [lindex $listCellsPerPath 0
}

getCellsFromBestTimingPaths $numWorstPaths $maxPaths $minSlack $maxSlack

