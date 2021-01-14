package provide prometheus-tcl 0.0.1

## \file exposition_text_format.tcl
# Provides the procs needed to turn the output of the collect method
# into the Prometheus exposition text format
namespace eval prom::text_format {

    ## Return the Prometheus text format for the results of metric collection
    #
    # \param[in] collectDicts List of dicts as returned from prom::collect
    proc encode {collectDicts} {
	set output [list]

	dict for {name metricFamily} $collectDicts {
	    if {![dict exists $metricFamily metrics]} {
		continue
	    }

	    dict with metricFamily {
		lappend output "# HELP $name [prom::escape_help_text $help]"
		lappend output "# TYPE $name $type"
		dict for {labelValues metric} $metrics {
		    foreach line [_encode_$type $name $labelKeys $labelValues $metric] {
			lappend output $line
		    }
		}
	    }
	}

	if {[llength $output]} {
	    return [join $output \n]\n
	}
    }


    proc _encode_counter {name labelKeys labelValues metric} {
	dict with metric {
	    set value [prom::expo_value $value]
	    return [list "$name[prom::label_text $labelKeys $labelValues] $value[_timestamp $ts]"]
	}
    }


    proc _encode_gauge {name labelKeys labelValues metric} {
	return [_encode_counter $name $labelKeys $labelValues $metric]
    }


    proc _encode_histogram {name labelKeys labelValues metric} {
	set lines [list]
	dict with metric {
	    dict for {bucketBoundary bucketCount} $buckets {
		set labelText [prom::label_text [concat $labelKeys le] [concat $labelValues $bucketBoundary]]
		lappend lines "${name}_bucket${labelText} $bucketCount[_timestamp $ts]"
	    }
	    set labelText [prom::label_text [concat $labelKeys le] [concat $labelValues +Inf]]
	    lappend lines "${name}_bucket${labelText} $count[_timestamp $ts]"

	    set labelText [prom::label_text $labelKeys $labelValues]
	    lappend lines "${name}_sum${labelText} [prom::expo_value $sum][_timestamp $ts]"
	    lappend lines "${name}_count${labelText} $count[_timestamp $ts]"
	}
	return $lines
    }


    proc _encode_summary {name labelKeys labelValues metric} {
	set lines [list]
	dict with metric {
	    lappend lines "${name}_sum[prom::label_text $labelKeys $labelValues] $sum[_timestamp $ts]"
	    lappend lines "${name}_count[prom::label_text $labelKeys $labelValues] $count[_timestamp $ts]"
	}
	return $lines
    }


    proc _timestamp {ts} {
	if {$ts} {return " $ts"}
    }
}

# vim: set ts=8 sw=4 sts=4 noet :
