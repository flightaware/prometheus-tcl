# -*- tcl -*-
# Tcl Benchmark File for the public API of the prometheus-tcl package
# This is in contrast to TclOO usage, which is less pleasant code-wise but faster

package require simulation::random

package require prometheus-tcl

##
##
## Globals and Helpers
##
##
set BUCKET_COUNTS {1 2 4 8 16 32} 

set LABEL_COUNTS {0 1 4 8 16}

proc gen_labels {numLabels} {
    set result [list]
    for {set i 0} {$i < $numLabels} {incr i} {
	lappend result key$i	
    }
    return $result
}

# generate a new random number, typically as part of an ipre
set observePRNG {set observation [$::bm_prng]}

set cleanup ::prom::collection_registry_unregister_all

##
##
## Counter
##
##

foreach labelCount $::LABEL_COUNTS {
    set labels [gen_labels $labelCount]

    set counterSetup [format {
	::prom::counter::new bmc -labels {%s}
    } $labels] 

    bench -desc "Increment a counter with $labelCount labels using public API" -body [format {
	::prom::counter::inc bmc %s
    } $labels] -pre $counterSetup -post $cleanup

    bench -desc "Create a counter with $labelCount labels using public API" -body $counterSetup -ipost $cleanup
}


##
##
## Gauge
##
##

foreach labelCount $::LABEL_COUNTS {
    set labels [gen_labels $labelCount]

    set gaugeSetup [format {
	::prom::gauge::new bmg -labels {%s}
    } $labels] 

    set gaugeSetupWithPRNG [format {
	%s

	set ::bm_prng [::simulation::random::prng_Uniform 0 1000000]
    } $gaugeSetup]

    bench -desc "Increment a gauge with $labelCount labels using the public API" -body [format {
	::prom::gauge::inc bmg %s
    } $labels] -pre $gaugeSetup -post $cleanup

    bench -desc "Decrement a gauge with $labelCount labels using the public API" -body [format {
	::prom::gauge::dec bmg %s
    } $labels] -pre $gaugeSetup -post $cleanup

    bench -desc "Set value on a gauge with $labelCount labels using the public API" -body [format {
	::prom::gauge::set_value bmg $observation %s
    } $labels] -pre $gaugeSetupWithPRNG -ipre $observePRNG -post $cleanup

    bench -desc "Set to current time on a gauge with $labelCount labels using the public API" -body [format {
	::prom::gauge::set_to_current_time bmg %s
    } $labels] -pre $gaugeSetup -post $cleanup

    bench -desc "Create a gauge with $labelCount labels using the public API" -body $gaugeSetup -ipost $cleanup
}

##
##
## Histogram
##
##

foreach bucketCount $::BUCKET_COUNTS {
    set buckets [::prom::exponential_buckets .005 10 $bucketCount]

    set lowBucket [lindex $buckets 0]
    set highBucket [expr {[lindex $buckets end] * 2}]

    set histogramSetup [format {
	::prom::histogram::new bmh -buckets {%s}

	set ::bm_prng [::simulation::random::prng_Uniform %s %s]
    } $buckets $lowBucket $highBucket]

    bench -desc "Observe histogram with 0 labels with $bucketCount buckets using the public API" -body {
	::prom::histogram::observe bmh $observation
    } -pre $histogramSetup -ipre $observePRNG -post $cleanup

    bench -desc "Create histogram with 0 labels with $bucketCount buckets using the public API" -body $histogramSetup -ipost $cleanup
}


##
##
## Summary
##
##

set summarySetup {
    set summaryFamily [::prom::SummaryFamily new bms]
    set summaryObj [$summaryFamily labels]

    set ::bm_prng [::simulation::random::prng_Uniform 0 1000000]
}

foreach labelCount [list 0 {*}$LABEL_COUNTS] {
    set labels [gen_labels $labelCount]

    set summarySetup [format {
	::prom::summary::new bms -labels {%s}
	
	set ::bm_prng [::simulation::random::prng_Uniform 0 100000] 
    } $labels]

    bench -desc "Observe a summary with $labelCount labels using the public API" -body [format {
	::prom::summary::observe bms $observation %s
    } $labels] -pre $summarySetup -ipre $observePRNG -post $cleanup

    bench -desc "Create a summary with $labelCount labels using the public API" -body $summarySetup -ipost $cleanup
}

# vim: set ts=8 sw=4 sts=4 noet :
