package provide prometheus-tcl 0.0.1

## \file exposition_mt.tcl
#
# Procs for handling exposition in a multi-threaded setting

package require Thread

namespace eval prom {
    ## Gather metric families from all participating threads
    proc _mt_gather_collections {} {
	set collections [list]

	set numThreads 0
	set vwaitVar [namespace current]::threadMetrics
	foreach threadID [mt_collection_threads] {
	    if {$threadID eq [thread::id]} {
		set myCollectionDict [prom::collect_st]
		if {[dict size $myCollectionDict]} {
		    lappend collections $myCollectionDict
		}
	    } else {
		thread::send -async -head $threadID prom::collect_st $vwaitVar
		incr numThreads
	    }
	}

	# Set a timeout if the value isn't set to 0
	if {[mt_collection_timeout]} {
	    set afterID [after [mt_collection_timeout] [list set $vwaitVar timeout]]
	} else {
	    set afterID ""
	}

	for {set i 0} {$i < $numThreads} {incr i} {
	    vwait $vwaitVar

	    set result [set $vwaitVar]
	    if {$result eq "timeout"} {
		break
	    } elseif {[dict size $result] == 0} {
		continue
	    } else {
		lappend collections $result
	    }
	}
	after cancel $afterID

	return $collections
    }


    ## Merge a list of MetricFamily dicts into a single MetricFamily dict
    #
    # \param[in] metricFamilyDicts List of dicts returned by calling  prom:collect_st
    #
    # \returns Single merged dict of MetricFamilies
    proc _mt_merge_collections {metricFamilyDicts} {
	set mergedFamilies [dict create]

	foreach metricFamilyDict $metricFamilyDicts {
	    dict for {name metricFamily} $metricFamilyDict {
		if {![dict exists $mergedFamilies $name]} {
		    dict set mergedFamilies $name $metricFamily
		} else {
		    dict set mergedFamilies $name [_mt_merge_families [dict get $mergedFamilies $name] $metricFamily]
		}
	    }
	}

	return $mergedFamilies
    }


    ## Merge two metric families with the same name, returning the result
    #
    # \param[in] mf1 Metric family
    # \param[in] mf2 Metric family with the same name as mf1
    proc _mt_merge_families {mf1 mf2} {
	if {![dict exists $mf2 metrics]} {
	    return $mf1
	}

	dict with mf1 {
	    dict for {m2LabelValues m2Metric} [dict get $mf2 metrics] {
		if {![dict exists $metrics $m2LabelValues]} {
		    dict set metrics $m2LabelValues $m2Metric
		} else {
		    set mergedMetric [_mt_merge_metrics_${type} [dict get $metrics $m2LabelValues] $m2Metric]
		    dict set metrics $m2LabelValues $mergedMetric
		}
	    }
	}

	return $mf1
    }


    proc _mt_merge_metrics_counter {c1 c2} {
	set result [dict create]
	dict with c1 {
	    dict set result value [expr {$value + [dict get $c2 value]}]
	    dict set result ts [expr {max($ts,[dict get $c2 ts])}]
	}
	return $result
    }


    proc _mt_merge_metrics_gauge {g1 g2 {_merge merge}} {
	upvar $_merge merge

	set result [dict create]
	dict with g1 {
	    set g2Value [dict get $g2 value]
	    if {$merge eq "max"} {
		if {$value > $g2Value} {
		    dict set result value $value
		    dict set result ts $ts
		} elseif {$value == $g2Value} {
		    dict set result value $value
		    dict set result ts [expr {max($ts,[dict get $g2 ts])}]
		} else {
		    dict set result value $g2Value
		    dict set result ts [dict get $g2 ts]
		}
	    } elseif {$merge eq "min"} {
		if {$value < $g2Value} {
		    dict set result value $value
		    dict set result ts $ts
		} elseif {$value == $g2Value} {
		    dict set result value $value
		    dict set result ts [expr {max($ts,[dict get $g2 ts])}]
		} else {
		    dict set result value $g2Value
		    dict set result ts [dict get $g2 ts]
		}
	    } elseif {$merge eq "sum"} {
		dict set result value [expr {$value + $g2Value}]
		dict set result ts [expr {max($ts,[dict get $g2 ts])}]
	    }
	}
    }


    proc _mt_merge_metrics_histogram {h1 h2} {
	set result [dict create]
	dict with h1 {
	    dict set result buckets [_mt_merge_buckets $buckets [dict get $h2 buckets]]
	    dict set result count [expr {$count + [dict get $h2 count]}]
	    dict set result sum [expr {$sum + [dict get $h2 sum]}]
	    dict set result ts [expr {max($ts,[dict get $h2 ts])}]
	}
	return $result
    }

    proc _mt_merge_buckets {b1 b2} {
	dict for {bucketBoundary bucketCount} $b2 {
	    dict incr b1 $bucketBoundary $bucketCount
	}
	return $b1
    }

    proc _mt_merge_metrics_summary {s1 s2} {
	set result [dict create]
	dict with s1 {
	    dict set result count [expr {$count + [dict get $s2 count]}]
	    dict set result sum [expr {$sum + [dict get $s2 sum]}]
	    dict set result ts [expr {max($ts,[dict get $s2 ts])}]
	}
	return $result
    }
}
