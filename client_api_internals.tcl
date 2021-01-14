package provide prometheus-tcl 0.0.1

package require TclOO

## \file client_api_internals.tcl
# Contains procs used behind the scenes by the procs in the public API
# None of the procs in this file are meant to be accessed by clients of the package

namespace eval prom {
    ## Create a new metric family of a given type
    #
    #  this proc is called by the client API new methods
    #  namespaced to each metric type and is not meant to be called directly
    #
    # \param[in] metricType Type of metric family to create
    # \param[in] name Name of the metric
    # \param[in] args Arguments to pass to new
    #
    #  \returns the empty string
    #
    #  It is an errror to call this proc more than once for a given name
    #
    #  If the creation of the metric family fails, an error will be thrown
    #
    proc _new_metric_family {metricType name args} {
	set name [_apply_metric_name_callback $metricType $name]

	# see if there is already a metric of that name
	# if so, raise an error
	# if not, create the family with the default registry
	set reg [get_collection_registry]
	if {[$reg haveRegisteredFamily $name]} {
	    return [_apply_name_conflict_policy]
	}

	$reg createAndRegisterFamily $metricType $name {*}$args
	return
    }


    ## Private proc to handle appending _info to the name of Info metrics
    proc _info_metric_name {name} {
	if {![regexp {_info$} $name]} {
	    append name "_info"
	}
	return $name
    }


    ## Private proc to apply name conflict policy
    proc _apply_name_conflict_policy {} {
	if {[name_conflict_policy] eq "error"} {
	    uplevel 1 {error "Already called new for metric $name"}
	}
    }


    ## Find and return a Metric object
    #
    # \param[in] metricType Type of metric to find
    # \param[in] name Name of the metric
    # \param[in] labelValues list of values for the metric's labels
    #
    #  an error will be thrown if the metric name has not been created
    #  with a previous invocation of a new proc and the missing names
    #  policy is set to error (the default)
    #
    #  an error can also be thrown (no matter what policy is set) if
    #  the name does exist but the metricType does not match the type
    #  of the metric already created with name
    #
    proc _find_metric_sample {metricType name labelValues} {
	set name [_apply_metric_name_callback $metricType $name]

	set reg [get_default_registry]
	set family [$reg getRegisteredFamily $name]

	if {$family eq ""} {
	    return [_apply_name_missing_policy]
	}

	if {[$family metricType] ne $metricType} {
	    error "Metric type mismatch: $name is a [$family metricType] but requested $metricType"
	}

	return [$family getMetricObject $labelValues]
    }


    ## Private proc to apply missing name policy
    proc _apply_name_missing_policy {} {
	if {[name_missing_policy] eq "error"} {
	    uplevel 1 {error "$name does not exist"}
	}
    }

    ## Pull out the -amount and labels arguments
    #
    # Provides a helper proc for extracting the amount to modify a metric by
    #
    # \param[in] argList List of arguments passed to a public API call
    #
    # \returns a two-element list of the amount and the labels
    proc _amount_and_labels {argList} {
	if {[extract_opt_value -amount $argList amount labels]} {
	    return [list $amount $labels]
	} else {
	    return [list 1 $argList]
	}
    }
}

# vim: set ts=8 sw=4 sts=4 noet :
