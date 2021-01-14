# -*- tcl -*-
# Tcl Benchmark File for metric collection

package require Thread
package require prometheus-tcl

set cleanup ::prom::collection_registry_unregister_all
set collect ::prom::collect


##
##
## Single Threaded
##
##

set stCollectSetup {
    for {set s 0} {$s < $numSamples} {incr s} {
	::prom::%s::new bm_${s}
    }
}

for {set i 0} {$i <= 10} {incr i} {
    set numSamples [expr {2**$i}]

    set stCounterSetup [format $stCollectSetup counter]
    set stHistogramSetup [format $stCollectSetup histogram]

    bench -desc "Collect $numSamples counter metric samples (single threaded)" \
	-body $collect -pre $stCounterSetup -post $cleanup 

    bench -desc "Collect $numSamples histogram metric samples with default buckets (single threaded)" \
	-body $collect -pre $stHistogramSetup -post $cleanup
}

##
##
## Multi-threaded
##
##

set mtCleanup {
    foreach tid $threads {
	thread::release $tid
    }

    ::prom::collection_registry_unregister_all
}

set mtCollectSetup {
    set threads [list]

    for {set s 0} {$s < $numSamples} {incr s} {
	set tid [thread::create {
	    package require prometheus-tcl
	    ::prom::%s::new bm_mt
	    thread::wait
	}]

	lappend threads $tid
    }
}

for {set i 0} {$i <= 10} {incr i} {
    set numSamples [expr {2**$i}]

    set mtCounterSetup [format $mtCollectSetup counter]
    set mtHistogramSetup [format $mtCollectSetup histogram]

    set mtPreGame {
	::prom::set_collection_policy mt
	::prom::set_mt_collection_timeout 5000
    }

    bench -desc "Collect $numSamples counter samples (multi-threaded) (1 sample / thread)" \
	  -body $collect -pre $mtCounterSetup -ipre $mtPreGame -post $mtCleanup 

    bench -desc "Collect $numSamples histogram samples with default buckets (multi-threaded) (1 histogram / thread)" \
	-body $collect -pre $mtHistogramSetup -ipre $mtPreGame -post $mtCleanup 
}


# vim: set ts=8 sw=4 sts=4 noet :
