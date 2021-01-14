package provide prometheus-tcl 0.0.1

## \file metric.tcl
#
# Defines the Metric baseclass which all the Prometheus Metric types
# inherit from.  A Metric object represents a sample in a
# MetricFamily so its representation is fairly sparse as it is expected
# that sufficient information to expose the metric is contained in an
# associated MetricFamily
#
# This class is not meant to be used outside of the context of a MetricFamily

package require TclOO
package require Thread

namespace eval prom {

oo::class create Metric {
    # whether to include a timestamp with this metric's value
    variable _timestamp

    # millisecond epoch timestamp
    variable _timestampMS

    ## Create a Metric object
    #
    # \param[in] args Supports the ?-timestamp? boolean option
    constructor {args} {
	set _timestamp 0
	prom::extract_opt_boolean -timestamp $args _timestamp args

	if {!$_timestamp} {
	    set _timestampMS 0
	}
    }


    destructor {
    }


    method collect {} {
	error "Must be implemented in derived class"
    }


    method timestamp {} {
	return $_timestamp
    }


    method RecordTimestamp {} {
	if {$_timestamp} {
	    set _timestampMS [clock milliseconds]
	}
    }
}

}; #

# vim: set ts=8 sw=4 sts=4 noet :
