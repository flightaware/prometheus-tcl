package provide prometheus-tcl 0.0.1

package require TclOO

## \file client_api.tcl
#
# Provides the intended API for the prometheus-tcl library
# In the vast majority of cases, the procs in this file will be all that's
# needed for instrumenting Tcl code with Prometheus metrics
# Some documentation of this interface is provided in the README as well
#
# To set the namespace globally for all metrics created through this API
# use the `::prom::set_namespace` proc

## Public procs for creating and incrementing Counters
# Counter operations live in the prom::counter namespace
namespace eval prom::counter {
    ## create a new Counter metric
    #
    # Must declare metrics with new before they can be used
    #
    # \param[in] name Metric name
    # \param[in] -help Help text for the metric (default name)
    # \param[in] -namespace Prefix to prepend to name when exposing  (default "")
    # \param[in] -labels List of label keys (default {})
    # \param[in] -timestamp Boolean argument to expose a timestamp with the metric
    #
    # \return Empty string
    #
    # Throws an exception if any of the following occurs:
    #
    #  - name is invalid
    #  - any of the label keys is invalid
    #  - new has been called with the same new before (for any metric type)
    #
    proc new {name args} {
	prom::_new_metric_family counter $name {*}$args
    }

    ## Increment a counter previously declared with new
    #
    # \param[in] name Metric name
    # \param[in] -amount Amount to increment (defaults to 1)
    # \param[in] ?labelValue labelValue ...? optional label values for the metric
    #
    # \returns the new value for the counter
    #
    #  amount can be any float value but must be > 0
    #
    #  Throws an exception if amount is invalid
    proc inc {name args} {
	lassign [prom::_amount_and_labels $args] amount labels
	set c [prom::_find_metric_sample counter $name $labels]
	if {$c ne ""} {$c inc $amount}
    }
}

## Public procs for creating and incrementing Gauges
# Gauge operations live in the prom::gauge namespace
namespace eval prom::gauge {
    ## create a new Gauge metric
    #
    # Takes the same arguments as prom::counter::new
    #
    proc new {name args} {
	prom::_new_metric_family gauge $name {*}$args
    }

    ## Increment a gauge previously declared with new
    #
    # Takes the same arguments as prom::counter::inc
    #
    proc inc {name args} {
	lassign [prom::_amount_and_labels $args] amount labels
	set g [prom::_find_metric_sample gauge $name $labels]
	if {$g ne ""} {$g inc $amount}
    }

    ## Decrement a gauge previously declared with new
    #
    # Takes the same arguments as prom::gauge::inc but the amount
    #  is deducted from the value of the gauge
    #
    # \erturns the new value of the gauge
    #
    # Throws an error if -amount is not a real number > 0
    #
    proc dec {name args} {
	lassign [prom::_amount_and_labels $args] amount labels
	set g [prom::_find_metric_sample gauge $name $labels]
	if {$g ne ""} {$g dec $amount}
    }

    ## Set the value of the gauge to a particular value
    #
    # \param[in] name Name of the gauge metric
    # \params[in] value Real value to set the gauge to
    # \param[in] ?labelValue labelValue ...? optional label values for the metric
    #
    # \returns the value the gauge was set to
    #
    proc set_value {name value args} {
	set g [prom::_find_metric_sample gauge $name $args]
	if {$g ne ""} {$g set $value}
    }

    ## Set the value of the gauge to the current epoch in seconds
    #
    # \param[in] name Name of the gauge metric
    # \param[in] ?labelValue labelValue ...? optional label values for the metric
    #
    # \returns the clock value the gauge was set to
    #
    proc set_to_current_time {name args} {
	set g [prom::_find_metric_sample gauge $name $args]
	if {$g ne ""} {$g setToCurrentTime}
    }

    ## Time a script of code in seconds and set the gauge to that value
    #
    # \param[in] name Name of the histogram metric
    # \param[in] script Code block to time
    # \param[in] args ?labelValue labelValue ...? optional label values for the metric
    proc time {name script args} {
	set g [prom::_find_metric_sample gauge $name $args]
	if {$g eq ""} {return}

	try {
	    set usecs [lindex [::time [list uplevel 1 $script]] 0]
	} finally {
	    $g set [expr {$usecs / (10**6 * 1.0)}]
	}
    }
}


## Public procs for creating and using histograms
# Histogram operations live in the prom::histogram namespace
namespace eval prom::histogram {
    ## Create a new histogram object
    #
    # Takes the same argument as prom::counter::new but
    # also includes one for specifying buckets
    #
    # \param[in] -buckets List of bucket boundaries defaults to {.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}
    #   The Inf bucket boundary does not need to be specified
    #
    # Throws an error if:
    #
    #  - buckets aren't sorted in ascending order
    #  - less than one bucket boundary is provided (excluding Inf)
    #  - any bucket boundary is a non-numeric value
    #
    proc new {name args} {
	prom::_new_metric_family histogram $name {*}$args
    }

    ## Observe a value for a histogram
    #
    # \param[in] name Name of the histogram metric
    # \param[in] value Numeric value to observe
    # \param[in] ?labelValue labelValue ...? optional label values for the metric
    #
    # \returns the empty string
    proc observe {name value args} {
	set h [prom::_find_metric_sample histogram $name $args]
	if {$h ne ""} {$h observe $value}
    }


    ## Time a script of code in seconds and observe its value
    #
    # \param[in] name Name of the histogram metric
    # \param[in] script Code block to time
    # \param[in] args ?labelValue labelValue ...? optional label values for the metric
    proc time {name script args} {
	set h [prom::_find_metric_sample histogram $name $args]
	if {$h eq ""} {return}

	set usecs [lindex [::time [list uplevel 1 $script]] 0]
	$h observe [expr {$usecs / (10**6 * 1.0)}]
    }
}


## Public procs for creating and using summarys
# Summary operations live in the prom::summary namespace
#
# Note that summary metrics in prometheus-tcl do NOT
# implement Phi-quantiles
namespace eval prom::summary {
    ## Create a new Summary metric
    #
    # Takes the same arguments as prom::counter::new
    #
    # Since no Phi-quantiles are calculated, the new Summary maintains
    # _total and _count Counter metrics
    #
    proc new {name args} {
	prom::_new_metric_family summary $name {*}$args
    }

    ## Observe a value for a summary
    #
    # \param[in] name Name of the summary metric
    # \param[in] value Numeric value to observe
    # \param[in] args ?labelValue labelValue ...? optional label values for the metric
    #
    # \returns the empty string
    proc observe {name value args} {
	set s [prom::_find_metric_sample summary $name $args]
	if {$s ne ""} {$s observe $value}
    }


    ## Time a script of code in seconds and observe its value
    #
    # \param[in] name Name of the summary metric
    # \param[in] script Code block to time
    # \param[in] args ?labelValue labelValue ...? optional label values for the metric
    proc time {name script args} {
	set s [prom::_find_metric_sample summary $name $args]
	if {$s eq ""} {return}

	set usecs [lindex [::time [list uplevel 1 $script]] 0]
	$s observe [expr {$usecs / (10**6 * 1.0)}]
    }
}

## Public procs for creating and using Info metrics
# Info operations live in the prom::info namespace
namespace eval prom::info {
    ## Create a new Info metric
    #
    # Appends the string _info to the metric name if it doesn't already exist
    #
    # Takes the same arguments as prom::counter::new but requires
    # that -labels is non-empty
    #
    proc new {name args} {
	set name [prom::_info_metric_name $name]
	prom::_new_metric_family info $name {*}$args
    }

    ## Provide label values to the Info metric so it will be exposed
    #
    # \param[in] name Metric name previously created with new
    # \param[in] args ?labelValue labelValue ...? Label values for the metric
    #
    proc labels {name args} {
	set i [prom::_find_metric_sample gauge [prom::_info_metric_name $name] $args]
	if {$i ne ""} {$i set 1.0}
    }
}

# vim: set ts=8 sw=4 sts=4 noet :
