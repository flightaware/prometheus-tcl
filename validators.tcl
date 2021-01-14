package provide prometheus-tcl 0.0.1

## \file validators.tcl
# Provides a collection of validation procs used throughout the
# package to ensure conformity with Prometheus' expectations

## prom namespace is the parent namespace for the prometheus-tcl package
namespace eval prom {
    ## Validate a list of potential histogram buckets
    #
    # \param[in] list of bucket boundaries
    #
    # \returns the buckets list passed in, potentially with an Inf boundary on success
    #
    #  Throws an error if buckets:
    #
    #   - is sorted in increasing order
    #   - includes at least one boundary other than Inf
    #   - only contains numeric values
    #
    proc validate_histogram_buckets {buckets} {
	if {[lindex $buckets end] != Inf} {
	    lappend buckets Inf
	}

	if {[llength $buckets] < 2} {
	    error "Must provide at least one bucket"
	}

	if {[lsort -real $buckets] != $buckets} {
	    error "Buckets must be sorted in increasing order"
	}

	foreach bucketBoundary $buckets {
	    if {![string is double -strict $bucketBoundary]} {
		error "Bucket boundaries must be numeric values"
	    }
	}

	return $buckets
    }


    ## Throw an error if a restricted label name is used
    #
    # \param[in] labelKeys list of label keys for a metric
    # \param[in] restrictedLabels list of forbidden label key values
    proc validate_restricted_labels {labelKeys {restrictedLabels le}} {
	foreach restrictedLabel $restrictedLabels {
	    if {$restrictedLabel in $labelKeys} {
		error "Cannot name a label reserved value $restrictedLabel"
	    }
	}
    }


    ## Uses a regexp to validate label key values
    #
    # See the Promtheus [data model](https://prometheus.io/docs/concepts/data_model/)
    # to verify conformity with the spec
    #
    # \param[in] labelKey label key to validate
    #
    # \returns true if valid and false otherwise
    #
    proc valid_label_key {labelKey} {
	return [regexp {^[a-zA-Z_][a-zA-Z0-9_]*$} $labelKey]
    }


    ## Check if valid_label_key returns true for every label in a list
    #
    # \param[in] labelKeys a list of label keys to validate
    #
    # \returns true if all labelKeys are valid and false otherwise
    proc valid_label_keys {labelKeys} {
	foreach labelKey $labelKeys {
	    if {![valid_label_key $labelKey]} {
		return 0
	    }
	}
	return 1
    }


    ## Does a potential name match the spec
    #
    # \param[in] metricName Name to validate against the documentation provided regexp
    proc valid_metric_name {metricName} {
	return [regexp {^[a-zA-Z_:][a-zA-Z0-9_:]*$} $metricName]
    }
}; # namespace eval prom

# vim: set ts=8 sw=4 sts=4 noet :
