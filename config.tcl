package provide prometheus-tcl 0.0.1

## \file config.tcl
# Small collection of procs for setting global configuration settings
# affecting the default registry
#
# Currently only supports setting the global namespace for new metrics

package require TclOO
package require Thread

## This block of code supports setting a global namespace for the client API
namespace eval prom {
    # Create a place to set the namespace globally across all
    # metrics constructed through the client API
    variable _METRIC_FAMILY_NAMESPACE ""

    # Boolean variable indicating whether automatic metric naming
    # based on base units and best practices
    ## Prepend a prefix to every newly created metric
    #
    # \param[in] namespace Prefix to prepend to every newly create metric
    #
    # If a namespace is set, then the name passed to any new proc for
    # declaring a metric will be exposed as namespace + _ + name
    #
    proc set_namespace {namespace} {
	variable _METRIC_FAMILY_NAMESPACE
	set _METRIC_FAMILY_NAMESPACE $namespace
    }

    ## Obtain the current global namespace for new metrics
    #
    # \returns the global namespace for new metrics
    proc get_namespace {} {
	variable _METRIC_FAMILY_NAMESPACE
	return $_METRIC_FAMILY_NAMESPACE
    }
}

## This block of code provides support for setting a metric name callback for the client API
namespace eval prom {
    # Allow for setting a proc that will be invoked whenever a
    # new metric is created by the client API that will be passed
    # the metric type and its name
    #
    # This allows for customized renaming behavior which can allow
    # for shorter code when interacting with created metrics
    variable _METRIC_NAME_CALLBACK prom::_metric_name_identity


    ## Allows for setting and unsetting of metric name callback
    #
    # \param[in] callback Callback to be invoked or empty string to unset
    proc metric_name_callback {callback} {
	variable _METRIC_NAME_CALLBACK
	if {$callback ne ""} {
	    set _METRIC_NAME_CALLBACK $callback
	} else {
	    set _METRIC_NAME_CALLBACK prom::_name_identity
	}
    }


    ## Private proc that always returns the metric name
    #
    # \param[in] metricType Type of the metric
    # \param[in] metricName Name of the metric
    #
    # \returns metricName
    proc _metric_name_identity {metricType metricName} {
	return $metricName
    }


    ## Apply the metric name callback to a provided metricName
    #
    # \param[in] metricType Type of the metric being created
    # \param[in] metricName Name of the metric being created
    #
    # \returns Result of the metric name callback on the input arguments
    proc _apply_metric_name_callback {metricType metricName} {
	variable _METRIC_NAME_CALLBACK
	return [{*}$_METRIC_NAME_CALLBACK $metricType $metricName]
    }
}

## This block of code supports setting policies about error handling in the client API
namespace eval prom {
    ## Set the policy for what to do when attempting to access a metric that has not been declared with new
    #
    # \param[in] policy Type of policy to use
    #
    # Supported policies:
    #
    #	error Throw an error (the default)
    #   ignore Silently ignore when it happens
    #
    # An error is thrown if the policy value is not one of the above
    proc set_name_missing_policy {policy} {
	if {$policy ni {error ignore}} {
	    error "Only support error and ignore policies"
	}

	variable _NAME_MISSING_POLICY
	set _NAME_MISSING_POLICY $policy
    }
    variable _NAME_MISSING_POLICY error


    ## Return the missing names policy
    proc name_missing_policy {} {
	variable _NAME_MISSING_POLICY
	return ${_NAME_MISSING_POLICY}
    }

    ## Set the policy for what to do when attempting to create a metric with a name that already exists
    #
    # \param[in] policy Type of policy to use
    #
    # Supported policies:
    #
    #	error Throw an error (the default)
    #   ignore Silently ignore when it happens
    #
    # An error is thrown if the policy value is not one of the above
    proc set_name_conflict_policy {policy} {
	if {$policy ni {error ignore}} {
	    error "Only support error and ignore policies"
	}

	variable _NAME_CONFLICT_POLICY
	set _NAME_CONFLICT_POLICY $policy
    }
    variable _NAME_CONFLICT_POLICY error


    ## Return the name conflict policy
    proc name_conflict_policy {} {
	variable _NAME_CONFLICT_POLICY
	return ${_NAME_CONFLICT_POLICY}
    }


    ## Whether prom::collect collects from multiple threads or not
    #
    # \param[in] policy Can be either st (single-thread) or mt (multi-thread)
    #
    # Defaults to single-threaded collection.
    proc set_collection_policy {policy} {
	if {$policy ni {st mt}} {
	    error "Only support st and mt collection policies"
	}

	variable _COLLECTION_POLICY
	set _COLLECTION_POLICY $policy
    }
    variable _COLLECTION_POLICY st


    ## Return the current collection policy
    proc collection_policy {} {
	variable _COLLECTION_POLICY
	return ${_COLLECTION_POLICY}
    }


    ## Set the multi-threaded collection timeout
    #
    # When operating in a multi-threaded setting, do not want to block
    # indefinitely when waiting for all the threads to return from [prom::collect]
    # so need to set a timeout for each of the threads in milliseconds
    proc set_mt_collection_timeout {timeoutMS} {
	variable _MT_COLLECTION_TIMEOUT_MSECS
	set _MT_COLLECTION_TIMEOUT_MSECS $timeoutMS
    }
    variable _MT_COLLECTION_TIMEOUT_MSECS 10


    ## Return the multi-threaded collection timeout
    proc mt_collection_timeout {} {
	variable _MT_COLLECTION_TIMEOUT_MSECS
	return ${_MT_COLLECTION_TIMEOUT_MSECS}
    }


    ## Set a particular list of threads to collect from in a multi-threaded settung
    proc set_mt_collection_threads {threadIDs} {
	variable _MT_COLLECTION_THREAD_IDS
	set _MT_COLLECTION_THREAD_IDS $threadIDs
    }
    variable _MT_COLLECTION_THREAD_IDS all


    ## Return the current list of threads to collect metrics from
    proc mt_collection_threads {} {
	variable _MT_COLLECTION_THREAD_IDS
	if {${_MT_COLLECTION_THREAD_IDS} eq "all"} {
	    return [thread::names]
	} else {
	    return ${_MT_COLLECTION_THREAD_IDS}
	}
    }
}

# vim: set ts=8 sw=4 sts=4 noet :
