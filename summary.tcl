package provide prometheus-tcl 0.0.1

## \file summary.tcl
# Defines the Summary class which represents a metric sample meant
# to be contained in a SummaryMetricFamily object

package require TclOO

namespace eval prom {

oo::class create Summary {
    superclass prom::Metric

    # only maintain two counters for a summary
    # does not maintain any Phi-quantiles
    variable _sum
    variable _count

    ## Create a Summary object
    #
    # Takes the same arguments as the prom::Metric class
    constructor {args} {
	next {*}$args

	set _sum   0.0
	set _count 0
    }


    ## Observe a value for the Summary
    #
    # \param[in] value Float value to observe
    #
    # Throws an error if value is not a proper float
    method observe {value} {
	if {![string is double -strict $value]} {
	    error "Must observe numeric value"
	}

	incr _count
	set _sum [expr {$_sum + $value}]
	my RecordTimestamp
    }

    ## Returns a list of the _sum and _count Counter values with an timestamp if necessary
    method collect {} {
	variable _timestampMS
	return [dict create ts $_timestampMS count $_count sum $_sum]
    }
}

}; # namespace prom

# vim: set ts=8 sw=4 sts=4 noet :
