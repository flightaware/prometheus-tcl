package provide prometheus-tcl 0.0.1

## \file metric_family.tcl
# Contains a core abstraction used by the package's internals
#
# A MetricFamily consists of the following:
#
#  - a metric name
#  - some help text for the metric
#  - a list of metric labels
#  - whether that metric should include a timestamp when exposed
#
# Every metric type has its own version dervied from MetricFamily
#
# Each MetricFamily maintains a mapping of samples for that metric name
# which are represented by Metric objects
#
# The Metric objects consist of label values and concrete values that will
# be exposed during a scrape or a push

package require TclOO
package require Thread

namespace eval prom {

oo::class create MetricFamily {
    # metric type in lowercase
    variable _type

    # base name for every metric in this family
    variable _name

    # help description to attach to the metric family
    variable _help

    # any registries this family is part of can have a namespace set as well
    variable _namespace

    # keep a list of label keys to enforce constraint of prohibiting >1
    # instance of a given metric name with different label keys
    variable _labelKeys

    # boolean: should we attach timestamps to every metric value?
    variable _timestamp

    # maps a string of all the label values (labels appear in
    # the order of the label keys in the _labelKeys variable)
    variable _familyMembers

    # keeps a reference to the Registry for this family
    # defaults to not having an associated Registry
    variable _registry


    ## Create a MetricFamily object
    #
    # \param[in] type Metric type name
    # \param[in] name Name of the metric family
    # \param[in] args Optional arguments
    #
    # args supports the following usage:
    #
    #   ?-help helpText? ?-labels labelKeys? ?-namespace namePrefix? ?-timestamp? ?-registry Registry?
    #
    # Throws an error if the metric name or a label key is invalid
    #
    constructor {type name args} {
	set _type [string tolower $type]
	set _name $name

	set _namespace [prom::get_namespace]
	prom::extract_opt_value	-namespace $args _namespace args

	set _help [my fullName]
	prom::extract_opt_value	-help $args _help args

	set _labelKeys {}
	prom::extract_opt_value	-labels $args _labelKeys args

	set _timestamp 0
	prom::extract_opt_boolean -timestamp $args _timestamp args

	set _registry ""
	prom::extract_opt_value -registry $args _registry args

	my ValidateMetricName
	my ValidateLabelKeys

	my CreateFamilyMembersDict
	my RegisterMetricFamily
    }


    ## Destroys the object and any of its family members
    destructor {
	foreach familyMemberObj [dict values $_familyMembers] {
	    $familyMemberObj destroy
	}
    }


    ## Collects metrics into a MetricFamily dict expected by ::prom::Registry
    method collect {} {
	if {[dict size $_familyMembers] == 0} {
	    return {}
	}

	set metricFamily [dict create help $_help type $_type labelKeys $_labelKeys]

	set metrics [dict create]
	dict for {labelValues metricObj} $_familyMembers {
	    dict set metrics $labelValues [dict create {*}[$metricObj collect]]
	}
	dict set metricFamily metrics $metrics

	return [dict create [my fullName] $metricFamily]
    }


    ## Return a Metric object representing the specified metric sample
    #
    # \param[in] labelValues list of label values for the Metric object
    #
    #  labelValues will be applied in order of the label keys returned
    #  by the labels method
    #
    #  If the Metric object already exists, return it.  Otherwise, create
    #  a Metric object and return the result of the constructor
    #
    #  If the number of label values provided does not match the number
    #  of label keys in the family, an error will be raised
    #
    #
    method getMetricObject {labelValues} {
	if {[dict exists $_familyMembers $labelValues]} {
	    return [dict get $_familyMembers $labelValues]
	}
	return [my AddFamilyMember $labelValues]
    }


    ## Return fully qualified namespace name
    method fullName {} {
	if {${_namespace} ne ""} {
	    return [join [list $_namespace $_name] _]
	} else {
	    return ${_name}
	}
    }


    ## Return the HELP description text
    method help {} {
	return $_help
    }


    ## Return the list of label keys
    method labelKeys {} {
	return $_labelKeys
    }


    ## Return the Metric object indicated by the passed in label values
    #
    # \param[in] args List of label values for the Metric object
    method labels {args} {
	return [my getMetricObject $args]
    }


    ## Return the metric type of the family
    method metricType {} {
	return $_type
    }


    ## Return the metric name without its namespace
    method name {} {
	return $_name
    }


    ## Returns true if [self] has the same labels as a given MetricFamily object
    #
    # \param[in] metricFamily MetricFamily object for comparison
    #
    # \returns boolean indicating whether the object passed in has the same label values as the invoking object
    method sameLabelsAs {metricFamily} {
	return [expr {[my labelKeys] eq [$metricFamily labelKeys]}]
    }


    ##
    ##
    ## PRIVATE METHODS
    ##
    ##


    ## Add a new Metric object to this family
    #
    # \param[in] labelValues List of label values for the new Metric object
    #
    # \returns newly created Metric object
    #
    method AddFamilyMember {labelValues} {
	my ValidateLabelValues $labelValues
	set metricConstructor "prom::[string totitle ${_type}]"
	set newMember [$metricConstructor new {*}[my NewMemberArgs]]

	dict set _familyMembers $labelValues $newMember

	return $newMember
    }


    ## Create the constructor's value for the _familyMembers dict based on
    #  whether or not the metric family has any labels
    #
    #  If no labels are involved we can export the family with a default value
    #  Otherwise the dict is empty until specific label values have been used
    #
    #  Modifies the _familyMembers attribute accordingly
    #
    method CreateFamilyMembersDict {} {
	set _familyMembers [dict create]

	if {[llength ${_labelKeys}] > 0} {
	    return
	}

	my AddFamilyMember ""
    }


    ## Return a list of arguments to use for creating new Metric objects for this family
    method NewMemberArgs {} {
	set newMemberArgs [list]
	if {$_timestamp} {
	    lappend newMemberArgs -timestamp
	}
	return $newMemberArgs
    }


    ## Register the MetricFamily with its associated Registry
    method RegisterMetricFamily {} {
	if {$_registry ne ""} {
	    $_registry register [self]
	}
    }


    ## Throw an error if the metric name is invalid
    method ValidateMetricName {} {
	if {![prom::valid_metric_name [my fullName]]} {
	    error "Invalid metric name '[my fullName]'"
	}
    }


    ## Thrown an error if any label keys is invalid
    method ValidateLabelKeys {} {
	# validate the labels, too
	if {![prom::valid_label_keys ${_labelKeys}]} {
	    error "Invalid label key provided"
	}

	if {$_type in {histogram summary}} {
	    prom::validate_restricted_labels ${_labelKeys} le
	}
    }


    method ValidateLabelValues {labelValues} {
	if {[llength $labelValues] == [llength $_labelKeys]} {
	    return
	}

	if {[llength $_labelKeys]} {
	    error "Must supply values for all labels: $_labelKeys"
	} else {
	    error "Provided label values for metric without labels"
	}
    }
}; # MetricFamily class


## CounterFamily is a container for Counter samples
oo::class create CounterFamily {
    superclass prom::MetricFamily

    constructor {name args} {
	next counter $name {*}$args
    }
}


## GaugeFamily is a container for Gauge samples
oo::class create GaugeFamily {
    superclass prom::MetricFamily

    # Gauge merge policy for multi-threaded mode
    variable _mtMergePolicy


    constructor {name args} {
	# Take care of the multi-threaded merge policy
	set _mtMergePolicy [expr {[prom::collection_policy] eq "mt" ? "max" : ""}]
	prom::extract_opt_value -mergePolicy $args _mtMergePolicy args

	next gauge $name {*}$args
    }


    method collect {} {
	if {${_mtMergePolicy} eq ""} {
	    next
	} else {
	    lassign [next] metricName metricFamilyDict
	    dict set metricFamilyDict merge ${_mtMergePolicy}
	    return [dict create $metricName $metricFamilyDict]
	}
    }
}


## HistogramFamily is a container for Histogram samples
oo::class create HistogramFamily {
    superclass prom::MetricFamily

    # histogram families need to maintain a list of buckets so that members
    # of the family can be created with the same specs
    # the _buckets variable here contains a list of floats
    variable _buckets


    ## Create a HistogramFamily object
    #
    # Same arguments accepted as MetricFamily but also accepts:
    #
    # ?-buckets bucketBoundaries?
    #
    # Default bucket boundaries {.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}
    #
    # Throws an error if the bucket boundaries are invalid
    constructor {name args} {
	set buckets {.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}
	prom::extract_opt_value -buckets $args buckets args

	set _buckets [prom::validate_histogram_buckets $buckets]

	next histogram $name {*}$args
    }


    ## Returns a list of bucket boundaries for the histogram family
    method buckets {} {
	return $_buckets
    }


    method NewMemberArgs {} {
	set newMemberArgs [next]
	lappend newMemberArgs -buckets $_buckets
	return $newMemberArgs
    }
}

## Supports an Info metric, which is a Gauge of value 1 under the hood
oo::class create InfoFamily {
    superclass prom::GaugeFamily


    ## Creates a new InfoFamilyMetricFamily object
    #
    # Before handing off contruction to the superclass, makes sure that the
    # -labels argument is not empty since an Info object only makes sense
    # if it has labels
    #
    constructor {name args} {
	if {![prom::extract_opt_value -labels $args labelKeys _] || [llength $labelKeys] == 0} {
	    error "Must provide at least one label key for an Info metric"
	}

	next $name {*}$args
    }
}


## SummaryFamily is a container for Summary samples
oo::class create SummaryFamily {
    superclass prom::MetricFamily


    constructor {name args} {
	next summary $name {*}$args
    }
}

## Return a list of supported metric types
proc metric_types {} {
    return {counter gauge histogram info summary}
}

}; # namespace prom

# vim: set ts=8 sw=4 sts=4 noet :
