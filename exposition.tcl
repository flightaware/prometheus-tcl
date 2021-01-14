package provide prometheus-tcl 0.0.1

## \file exposition.tcl
#
# Takes care of exposing the metrics created and modified with the public client API
# in a variety of ways so that Prometheus can scrape

package require cmdline
package require Thread

namespace eval prom {
    ## Return Prometheus exposition format metrics based on the current collection policy
    #
    # \returns a string of the current Prometheus metrics in the currently defined collection registry
    #
    proc collect {} {
	return [prom::text_format::encode [collect_[collection_policy]]]
    }


    ## Collect metrics in Prometheus' exposition format in a single-threaded context
    #
    # \returns The metrics in the currently set collection registry
    proc collect_st {} {
	return [[get_collection_registry] collect]
    }


    ## Collect metrics in a multi-threaded context
    proc collect_mt {} {
	return [_mt_merge_collections [_mt_gather_collections]]
    }


    ## Returns the list of metric names created by prom::*::new calls
    proc metrics_created {} {
	return [[get_collection_registry] registeredFamilyNames]
    }


    ## Write the results of prom::collect to a file
    #
    # In a non-blocking way, write the current Prometheus metrics in the
    # current collection registry into a file
    #
    # \param[in] fname File name to write metrics into
    #
    # \returns 1 if no tracebacks were encountered or 0 if one occurred
    proc collect_to_file {fname} {
	try {
	    set fileChan [open $fname w]
	    _configure_file_channel $fileChan

	    chan puts -nonewline $fileChan [collect]
	    chan flush $fileChan

	    return 1
	} on error {} {
	    return 0
	} finally {
	    catch {close $fileChan}
	}
    }


    ## Private proc for configure the file channel when collecting to a file
    #
    # \param[in] fileChan File channel to configure for metric collection
    #
    # Makes the channel non-blocking with a binary translation and full buffering
    proc _configure_file_channel {fileChan} {
	set configOpts [list]

	lappend configOpts -blocking 0
	lappend configOpts -buffering full
	lappend configOpts -translation binary

	chan configure $fileChan {*}$configOpts
    }


    ## Escape a label value according to the spec
    #
    # \param[in] labelValue Value of a metric's label
    #
    # \returns An escaped version of labelValue
    proc escape_label_value {labelValue} {
	return [string map {\\ \\\\ \" \\\" \n \\n} $labelValue]
    }


    ## Escape matric help text according to the spec
    #
    # \param[in] helpText HELP description text
    #
    # \returns AN escaped version of helpText
    proc escape_help_text {helpText} {
	return [string map {\\ \\\\ \n \\n} $helpText]
    }


    ## Format a metric value according to the spec
    #
    # \param[in] value Metric value
    #
    # \returns Float64 value supported by Prometheus
    proc expo_value {value} {
	if {$value == NaN || ![string is double -strict $value]} {
	    return "Nan"
	} elseif {$value == Inf} {
	    return "+Inf"
	} elseif {$value == -Inf} {
	    return "-Inf"
	} else {
	    return $value
	}
    }


    ## Produce formatted labels according to the spec
    #
    # \param[in] labelKeys List of label keys
    # \param[in] labelValues List of label values
    #
    # \returns Textual representation of those labels for Prometheus
    proc label_text {labelKeys labelValues} {
	if {[llength $labelKeys] == 0} {
	    return ""
	}

	set labels [list]
	lmap k $labelKeys v $labelValues {
	    lappend labels [string cat $k = \" [escape_label_value $v] \"]
	}

	return "\{[join $labels ,]\}"
    }


    ## Expose metrics on a port over HTTP
    #
    # \param[in] -address Domain-style name or numerical IP address to listen on (defaults to 0.0.0.0)
    # \param[in] -port Port to listen on (defaults to 1347)
    # \param[in] -tls Boolean argument to turn on TLS (defaults to off)
    # \param[in] -tlsArgs List of arguments to pass to tls::import (defaults to {})
    # \param[in] -path URI path to respond to requests for (defaults to /metrics)
    # \param[in] -timeoutMS Once a client connects, wait this long in milliseconds for a full request (defaults to 100)
    #
    # For this to work, it must be done in a program that enters the event loop
    #
    # \returns The empty string
    #
    # Throws an error if the server socket cannot be opened
    proc expose {args} {
	set usage "prom::expose ?-address address? ?-port port? ?-tls? ?-tlsArgs args? ?-path path?"
	set options {
	    {address.arg "0.0.0.0" "Domain-style name or numerical IP address"}
	    {port.arg 1347 "Port to listen on"}
	    {tls "Enable TLS"}
	    {tlsArgs.arg "" "List of arguments to pass to tls::import"}
	    {path.arg "/metrics" "URI path to respond to requests for"}
	    {timeoutMS.arg 100 "Once a client connects, max milliseconds to wait for a request"}
	}

	array set opts [::cmdline::getoptions args $options $usage]
	prom::http::pull::listen opts

	return
    }

    ## Stop exposing metrics on a given address and port
    #
    # \param[in] -address Domain-stype name of numerical IP address to unexpose
    # \param[in] -port Port to stop listening on (defaults to 1347)
    #
    # \returns The empty string
    #
    # Does not throw an error
    proc unexpose {args} {
	set usage "prom::unexpose ?-address address? ?-port port?"
	set options {
	    {address.arg "0.0.0.0" "Domain-style name or numerical IP address to unexpose"}
	    {port.arg 1347 "Port to stop listening on"}
	}

	array set opts [::cmdline::getoptions args $options $usage]
	prom::http::pull::unlisten opts

	return
    }

    ## PUT the current metrics to a gateway
    #
    # \param[in] gateway Hostname of the gateway.  Can include an http or https scheme and a port number.
    # \params[in] job Name of the job during the push
    # \params[in] -groupingKey Dict of label key and value pairs for replacing those in posted metrics
    # \params[in] -timeout Timeout in milliseconds to wait for connecting to the PushGateway (defaults to 5000)
    #
    # \returns 1 if a 200 or 202 status code was returned and 0 otherwise
    #
    # Throws an error if gateway is invalid for any reason
    #
    # All PushGateway procs take care of encoding job and grouping key values
    proc push_to_gateway {gateway job args} {
	array set opts [prom::http::push::_gateway_arg_parsing push {*}$args]
	prom::http::push::_gateway_common PUT $gateway $job $opts(groupingKey) $opts(timeout)
    }


    ## POST the current metrics to a gateway
    #
    # Takes the same arguments as prom::push_to_gateway
    #
    # \returns 1 if a 200 status code is returned
    proc pushadd_to_gateway {gateway job args} {
	array set opts [prom::http::push::_gateway_arg_parsing pushadd {*}$args]
	prom::http::push::_gateway_common POST $gateway $job $opts(groupingKey) $opts(timeout)
    }


    ## DELETE the current metrics on a gateway
    #
    # Takes the same arguments as prom::push_to_gateway
    #
    # \returns 1 if a 202 status code is returned
    proc delete_from_gateway {gateway job args} {
	array set opts [prom::http::push::_gateway_arg_parsing delete {*}$args]
	prom::http::push::_gateway_common DELETE $gateway $job $opts(groupingKey) $opts(timeout)
    }
}

# vim: set ts=8 sw=4 sts=4 noet :
