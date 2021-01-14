# -*- tcl -*-
# Tcl Benchmark File for TclOO use of the prometheus-tcl package
# This is in contrast to the public API provided by the package

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


##
##
## Counter
##
##

set counterCleanup {$counterFamily destroy}

foreach labelCount $::LABEL_COUNTS {
    set labels [gen_labels $labelCount]

    set counterSetup [format {
	set counterFamily [::prom::CounterFamily new bmc -labels {%s}]
	set counterObject [$counterFamily labels %s]
    } $labels $labels]

    bench -desc "Increment a counter with $labelCount labels using direct object access" -body {
	$counterObject inc 
    } -pre $counterSetup -post $counterCleanup

    bench -desc "Increment a counter with $labelCount labels using MetricFamily labels method" -body [format {
	[$counterFamily labels %s] inc
    } $labels] -pre $counterSetup -post $counterCleanup

    bench -desc "Create a counter with $labelCount labels using TclOO" -body [format {
	set counterFamily [::prom::CounterFamily new bmc -labels {%s}]
    } $labels] -ipost $counterCleanup
}


##
##
## Gauge
##
##

set gaugeCleanup {$gaugeFamily destroy}

foreach labelCount $::LABEL_COUNTS {
    set labels [gen_labels $labelCount]

    set gaugeSetup [format {
	set gaugeFamily [::prom::GaugeFamily new bmg -labels {%s}]
	set gaugeObj [$gaugeFamily labels %s]
    } $labels $labels]

    set gaugeSetupWithPRNG [format {
	%s

	set ::bm_prng [::simulation::random::prng_Uniform 0 1000000]
    } $gaugeSetup]

    bench -desc "Increment a gauge with $labelCount labels using direct object access" -body {
	$gaugeObj inc 
    } -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Increment a gauge with $labelCount labels using MetricFamily labels method" -body [format {
	[$gaugeFamily labels %s] inc 
    } $labels] -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Decrement a gauge with $labelCount labels using direct object access" -body {
	$gaugeObj dec
    } -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Decrement a gauge with $labelCount labels using MetricFamily labels method" -body [format {
	[$gaugeFamily labels %s] dec
    } $labels] -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Set value on a gauge with $labelCount labels using direct object access" -body {
	$gaugeObj set $observation
    } -pre $gaugeSetupWithPRNG -ipre $observePRNG -post $gaugeCleanup

    bench -desc "Set value on a gauge with $labelCount labels using MetricFamily labels method" -body [format {
	[$gaugeFamily labels %s] set $observation
    } $labels] -pre $gaugeSetupWithPRNG -ipre $observePRNG -post $gaugeCleanup

    bench -desc "Set to current time on a gauge with $labelCount labels using direct object access" -body {
	$gaugeObj setToCurrentTime
    } -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Set to current time on a gauge with $labelCount labels using MetricFamily labels method" -body [format {
	[$gaugeFamily labels %s] setToCurrentTime
    } $labels] -pre $gaugeSetup -post $gaugeCleanup

    bench -desc "Create a gauge with $labelCount labels using TclOO" -body [format {
	set gaugeFamily [::prom::GaugeFamily new bmg -labels {%s}]
    } $labels] -ipost $gaugeCleanup
}

##
##
## Histogram
##
##

set histogramCleanup {$histogramFamily destroy}

foreach bucketCount $::BUCKET_COUNTS {
    set buckets [::prom::exponential_buckets .005 10 $bucketCount]

    set lowBucket [lindex $buckets 0]
    set highBucket [expr {[lindex $buckets end] * 2}]

    set setup [format {
	set histogramFamily [::prom::HistogramFamily new bmh -buckets {%s}]
	set histogramObject [$histogramFamily labels]

	set ::bm_prng [::simulation::random::prng_Uniform %s %s]
    } $buckets $lowBucket $highBucket]

    bench -desc "Observe histogram with 0 labels with $bucketCount buckets using direct object access" -body {
	$histogramObject observe $observation
    } -pre $setup -ipre $observePRNG -post $histogramCleanup

    bench -desc "Observe histogram with 0 labels with $bucketCount buckets using MetricFamily labels method" -body {
	[$histogramFamily labels] observe $observation
    } -pre $setup -ipre $observePRNG -post $histogramCleanup

    bench -desc "Create histogram with 0 labels with $bucketCount buckets using TclOO" -body [format {
	set histogramFamily [::prom::HistogramFamily new bmh -buckets {%s}]
    } $buckets] -ipost $histogramCleanup
}


##
##
## Summary
##
##

set summaryCleanup {$summaryFamily destroy}

set summarySetup {
    set summaryFamily [::prom::SummaryFamily new bms]
    set summaryObj [$summaryFamily labels]

    set ::bm_prng [::simulation::random::prng_Uniform 0 1000000]
}

foreach labelCount [list 0 {*}$LABEL_COUNTS] {
    set labels [gen_labels $labelCount]

    set setup [format {
	set summaryFamily [::prom::SummaryFamily new bms -labels {%s}]
	set summaryObject [$summaryFamily labels %s]

	set ::bm_prng [::simulation::random::prng_Uniform 0 100000] 
    } $labels $labels]

    bench -desc "Observe a summary with $labelCount labels using direct object access" -body {
	$summaryObject observe $observation	
    } -pre $setup -ipre $observePRNG -post $summaryCleanup

    bench -desc "Observe a summary with $labelCount labels using MetricFamily labels method" -body [format {
	[$summaryFamily labels %s] observe $observation
    } $labels] -pre $setup -ipre $observePRNG -post $summaryCleanup

    bench -desc "Create a summary with $labelCount labels using TclOO" -body [format {
	set summaryFamily [::prom::SummaryFamily new bms -labels {%s}]
    } $labels] -ipost $summaryCleanup
}

# vim: set ts=8 sw=4 sts=4 noet :
