#!/usr/bin/env tclsh

package require bench
package require bench::out::csv
package require bench::out::text
package require cmdline
package require logger

proc benchmark_dir {} {
    set scriptLocation [file normalize [info script]]
    return [file dirname $scriptLocation]
}

proc benchmark_files {} {
    if {$::params(files) ne ""} {
	return $::params(files)
    }

    return [glob -nocomplain -directory [benchmark_dir] -types f *.bench]
}

proc benchmark_interps {} {
    set interp [info nameofexecutable]
    set pattern [file tail $interp]
    set paths [list [file dirname $interp]]

    return [bench::versions [bench::locate $pattern $paths]]
}

proc disable_logging {} {
    set benchLogger [logger::servicecmd bench]
    ${benchLogger}::disable emergency
}

proc output_results {benchmarkResults} {
    puts " Iterations: $::params(iterations)"

    if {$::params(csvOutput)} {
	return [bench::out::csv $benchmarkResults]
    } else {
	return [bench::out::text $benchmarkResults]
    }
}

proc run_benchmarks {} {
    set runArgs [list]
    lappend runArgs -match $::params(match)
    lappend runArgs -rmatch $::params(rmatch)
    lappend runArgs -iters $::params(iterations)
    lappend runArgs [benchmark_interps] 
    lappend runArgs [benchmark_files]

    return [bench::run {*}$runArgs]
}

proc validate_params {} {
    set posIntFields {iterations}
    foreach posIntField $posIntFields {
	if {![string is integer -strict $::params($posIntField)] || \
	    $::params($posIntField) <= 0} {
	    puts stderr "Must provide a position, non-zero integer for -$posIntField"
	    exit 1
	}
    }

    if {$::params(files) ne ""} {
	foreach fpath $::params(files) {
	    if {![file isfile $fpath]} {
		puts stderr "Invalid file path in -files: $fpath"
		exit 1
	    }
	}
    }
}


##
##
## MAIN
##
##

proc main {{argv ""}} {
    set usage ": $::argv0 ?options?"
    set options {
	{csvOutput "Whether to output results in CSV format (default is text format)"}
	{iterations.arg 1000 "Number of iterations for each execution of a benchmark"}
	{match.arg "" "Glob pattern of benchmark descriptions to run (\"\" means all patterns)"}
	{rmatch.arg "" "Regular expression pattern of benchmark descriptions to run (\"\" means all patterns)"}
	{files.arg "" "Space-separated list of files with benchmarks (defaults to all *.bench files)"}
	{verbose "Whether to emit verbose output during benchmark execution"}
    }

    try {
	array set ::params [::cmdline::getoptions argv $options $usage]
    } on error {result options} {
	puts stderr $result
	exit 1
    }

    validate_params
    if {!$::params(verbose)} {
	disable_logging
    }

    puts [output_results [run_benchmarks]]
}

if {!$tcl_interactive} {
    main $::argv
}

# vim: set ts=8 sw=4 sts=4 noet :
