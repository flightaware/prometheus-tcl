package provide prometheus-tcl 0.0.1

package require TclOO

namespace eval prom {

oo::class create Histogram {
    superclass prom::Metric

    # _buckets maps bucket boundaries to their current counts
    variable _bucketsD

    # maintain separate sum and count counters
    variable _sum
    variable _count

    ## Create a Histogram object
    #
    # Same arguments accepted as Metric but also accepts:
    #
    # ?-buckets bucketBoundaries?
    #
    # Default bucket boundaries {.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}
    #
    # Throws an error if the bucket boundaries are invalid
    constructor {args} {
	set buckets {.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}

	prom::extract_opt_value -buckets $args buckets args
	next {*}$args

	my CreateBuckets $buckets

	set _sum 0.0
	set _count 0
    }

    ## Return the bucket boundaries
    method buckets {} {
	return [dict keys $_bucketsD]
    }


    ## Observe a value for the Histogram
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

	foreach bucketBoundary [dict keys $_bucketsD] {
	    if {$value <= $bucketBoundary} {
		dict incr _bucketsD $bucketBoundary
	    }
	}

	my RecordTimestamp
    }


    ## Throw an error if buckets are invalid
    method CreateBuckets {buckets} {
	# assumes that the MetricFamily class has
	# validated the buckets
	foreach bucket [lrange $buckets 0 end-1] {
	    dict set _bucketsD $bucket 0
	}
    }


    ## Returns a list of the _bucket, _sum and _count Counter values with an timestamp if necessary
    method collect {} {
	variable _timestampMS
	return [dict create ts $_timestampMS buckets $_bucketsD sum $_sum count $_count]
    }
}

## Return a list of increasing sorted linear buckets
#
# \param[in] start Starting value of the buckets
# \param[in] width Difference between the bucket boundaries
# \param[in] count Number of buckets
#
# Throws an error if count is < 1
proc linear_buckets {start width count} {
    if {$count < 1} {
	error "linear_buckets needs a positive non-zero count")
    }

    set buckets [list]
    for {set i 0} {$i < $count} {incr i} {
	lappend	buckets $start
	incr start $width
    }
    return $buckets
}

## Return a list of increasingly sorted exponential buckets
#
# \param[in] start Starting value of the buckets
# \param[in] factor Multiplicative factor consecutive bucket boundaries
# \param[in] count Number of buckets
#
# Throws an error if count is < 1
#
# Throws an error if start is <= 0
#
# Throws an error factors is <= 1
proc exponential_buckets {start factor count} {
    if {$count < 1} {
	error "exponential_buckets needs a positive non-zero count"
    }

    if {$start <= 0} {
	error "exponential_buckets needs a positive non-zero start"
    }

    if {$factor <= 1} {
	error "exponential_buckets needs a factor greater than 1"
    }

    set buckets [list]

    for {set i 0} {$i < $count} {incr i} {
	lappend buckets $start
	set start [expr {$start * $factor}]
    }

    return $buckets
}

}; # namespace prom

# vim: set ts=8 sw=4 sts=4 noet :
