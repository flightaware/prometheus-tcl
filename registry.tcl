package provide prometheus-tcl 0.0.1

## \file registry.tcl
# A Registry object maintains a dictionary of MetricFamily objects
# so that they can be exposed during Prometheus scrapes by calling the collect
# method on each of the MetricFamily objects registered

package require TclOO
package require Thread

namespace eval prom {

## Registry class allows metrics to register themselves
# When a metric registers with a Registry, its contents will be exposed
# during a scrape from Prometheus
oo::class create Registry {
    # maps metric name to a metrics family
    variable _families

    # keep track of the families created by the registry
    variable _createdFamilies

    constructor {args} {
	set _families [dict create]
	set _createdFamilies [list]
    }


    ## Destroy any MetricFamily objects created directly by the object
    destructor {
	foreach createdFamilyName $_createdFamilies {
	    set familyObj [dict get $_families $createdFamilyName]
	    $familyObj destroy
	}
    }


    ## Collect metrics from all registered MetricFamily objects
    #
    # \returns a dict representing all metric families in the registry
    #
    # The returned dict's keys are metric names and the values are dicts
    # with the following keys and values:
    #	
    #	- help: HELP documentation as a string
    #   - type: metric TYPE as a string
    #   - labelKeys: list of strings (empty list means no labels)
    #   - metrics: a dict of label values as keys and the result of calling collect
    #              on the associated MetricFamily object
    method collect {} {
	set collection [dict create]
	foreach metricFamily [dict values $_families] {
	    set collection [dict merge $collection [$metricFamily collect]]
	}
	return $collection
    }


    ## Find a MetricFamily object by name
    #
    # \param[in] name Metric name to look for
    #
    # \returns MetricFamily object with name or an empty string
    #
    method getRegisteredFamily {name} {
	if {[dict exists $_families $name]} {
	    return [dict get $_families $name]
	}
    }

    ## Create a new MetricFamily and register it with this Registry
    #
    # \param[in] metricType Metric type in all lowercase
    # \param[in] name Name of the metric
    # \params[in] args Additional arguments to pass to the MetricFamily constructor
    #
    #  This method throws an error if a metric family by the name passed in
    #  already exists and the metricType or the labels do not match the already
    #  registered family
    #
    #  It is not, however, an error to call this multiple times for the same arguments
    #
    #  \returns the registered MetricFamily object
    #
    method createAndRegisterFamily {metricType name args} {
	set familyConstructor "prom::[string totitle $metricType]Family"
	set family [$familyConstructor new $name {*}$args]

	try {
	    if {[my register $family]} {
		lappend _createdFamilies $name
		set destroyConstructedMetricFamilyObj 0
	    } else {
		# was already registered so no need to
		# keep the newly created object around
		set destroyConstructedMetricFamilyObj 1
	    }

	    return [my getRegisteredFamily $name]
	} on error {result} {
	    # destroy the metric here since it was not registered
	    # and this method had the responsibility of creating it
	    set destroyConstructedMetricFamilyObj 1

	    throw $::errorCode $result
	} finally {
	    if {$destroyConstructedMetricFamilyObj} {
		$family destroy
	    }
	}
    }


    ## Is a metric name registered?
    #
    # \param[in] name Is this metric name registered with [self]
    method haveRegisteredFamily {name} {
	return [dict exists $_families $name]
    }


    ## Register a MetricFamily object with the Registry
    #
    # \param[in] metricFamily MetricFamily object to register
    #
    # \returns 1 if metricFamily is successfully registered for the first time
    # \returns 0 if metricFamily is already registered
    #
    # Throws an error if the name of the passed in MetricFamily object is already
    # registered but the metric type or the labels do not match what is currently there
    method register {metricFamily} {
	set metricName [$metricFamily name]

	if {[dict exists $_families $metricName]} {
	    set family [dict get $_families $metricName]
	    if {![$family sameLabelsAs $metricFamily]} {
		error "Metric name already registered with conflicting labels"
	    }

	    if {[$family metricType] ne [$metricFamily metricType]} {
		error "Metric name already registered as a [$family metricType] but provided a [$metricFamily metricType]"
	    }

	    return 0
	} else {
	    dict set _families $metricName $metricFamily
	    return 1
	}
    }


    ## Return a list of full registered metric family names with this Registry
    #
    # The namespace of the metric family is included in each string in the output
    method registeredFamilyNames {} {
	return [lmap mfObj [dict values $_families] {$mfObj fullName}]
    }


    ## Unregister a MetricFamily from collection
    #
    # \param[in] metricFamily MetricFamily object to unregister
    method unregister {metricFamily} {
	my unregisterName [$metricFamily name]
    }


    ## Unregister a metric by name
    #
    # \param[in] metricName Name of metric to unregister
    method unregisterName {metricName} {
	if {![dict exists $_families $metricName]} {
	    return
	}

	if {$metricName in $_createdFamilies} {
	    set mf [dict get $_families $metricName]
	    $mf destroy
	}

	dict unset _families $metricName
    }

    ## Unregister all metrics in the registry
    #
    # Stop collecting from all metrics in the registry
    # Destroys any metrics created by the registry
    method unregisterAll {} {
	foreach createdFamilyName $_createdFamilies {
	    set familyObj [dict get $_families $createdFamilyName]
	    $familyObj destroy
	}

	set _createdFamilies [list]
	set _families [dict create]
    }
}

## Default registry is created on package load
#
# It is used behind the scenes but can be swapped out for a Registry
# object that collects some alternate set of MetricFamily objects
variable _DEFAULT_REGISTRY [Registry new]

## Return the default Registry object
proc get_default_registry {} {
    variable _DEFAULT_REGISTRY
    return $_DEFAULT_REGISTRY
}


proc default_registry {} {
    return [get_default_registry]
}


## The collection registry is what prom::collect uses
variable _COLLECTION_REGISTRY [get_default_registry]


proc set_collection_registry {registry} {
    variable _COLLECTION_REGISTRY
    set _COLLECTION_REGISTRY $registry
}


proc get_collection_registry {} {
    variable _COLLECTION_REGISTRY
    return $_COLLECTION_REGISTRY
}


proc collection_registry {} {
    return [get_collection_policy]
}


proc collection_registry_unregister_all {} {
    set collectionRegistry [get_collection_registry] 
    $collectionRegistry unregisterAll
}

}; # namespace prom

# vim: set ts=8 sw=4 sts=4 noet :
