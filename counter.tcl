package provide prometheus-tcl 0.0.1

## \file counter.tcl
# Defines the Counter class which represents a metric sample meant
# to be contained in a CounterMetricFamily object

package require TclOO

namespace eval prom {

oo::class create Counter {
    superclass prom::Metric

    variable _value

    ## Create a Counter object
    #
    # Takes the same arguments as the prom::Metric class
    constructor {args} {
	next {*}$args
	set _value 0.0
    }


    ## Increment a Counter
    #
    # \param[in] amount Float amount to increment by (defaults to 1)
    #
    # Throws an error if amount is < 0
    method inc {{amount 1}} {
	if {$amount < 0} {
	    error "inc requires positive amount"
	}

	set _value [expr {$_value + $amount}]
	my RecordTimestamp
    }

    ## Return a list containing the current value and, if needed, a timestamp
    method collect {} {
	variable _timestampMS
	return [dict create value $_value ts $_timestampMS]
    }
}

}; # namespace prom

# vim: set ts=8 sw=4 sts=4 noet :
