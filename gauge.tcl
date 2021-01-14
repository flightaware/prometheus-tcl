package provide prometheus-tcl 0.0.1

## \file gauge.tcl
# Defines the Gauge class which represents a metric sample meant
# to be contained in a GaugeMetricFamily object

package require TclOO

namespace eval prom {

oo::class create Gauge {
    superclass prom::Metric

    variable _value


    ## Create a Gauge object
    #
    # Takes the same arguments as the prom::Metric class
    # along with a merge policy for operating in a
    # multi-threaded settings
    #
    # \param[in] -merge policy (defaults to max)
    #
    # Accept policy values of min, max or sum
    constructor {args} {
	next {*}$args
	::set _value 0.0
    }


    ## Increment a Gauge
    #
    # \param[in] amount Float amount to increment by (defaults to 1)
    #
    # Throws an error if amount is < 0
    method inc {{amount 1}} {
	if {$amount < 0} {
	    error "inc requires positive amount"
	}

	::set _value [expr {$_value + $amount}]
	my RecordTimestamp
    }

    ## Decrement a Gauge
    #
    # \param[in] amount Float amount to increment by (defaults to 1)
    #
    # Throws an error if amount is < 0
    method dec {{amount 1}} {
	if {$amount < 0} {
	    error "dec requires positive amount"
	}

	::set _value [expr {$_value + (-1.0 * $amount)}]
	my RecordTimestamp
    }


    ## Set a Gauge to a particular value
    #
    # \param[in] value Float value to set the Gauge to
    method set {value} {
	::set _value $value
	my RecordTimestamp
    }

    # Set the Gauge to the current epoch time in seconds
    method setToCurrentTime {} {
	::set _value [clock seconds]
	my RecordTimestamp
    }


    ## Return a list containing the current value and, if needed, a timestamp
    method collect {} {
	variable _timestampMS
	return [dict create value $_value ts $_timestampMS]
    }
}

};

# vim: set ts=8 sw=4 sts=4 noet :
