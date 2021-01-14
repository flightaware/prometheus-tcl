package provide prometheus-tcl 0.0.1

## \file shared_utils.tcl
# Place to store shared helper or utility functions within the prom namespace

package require Thread

namespace eval prom {
    ## Increment by any numeric amount
    #
    # Since incr only accepts integer arguments this proc
    # provides the same interface but without this limitation
    #
    # \param[out] varName Variable name in the caller to set the result into
    # \param[in] amount Amount to increment varName (defaults to 1)
    proc inc {varName {amount 1}} {
	upvar 1 $varName var
	set var [expr {$var + $amount}]
    }


    ## Run a script in the context of an exclusive mutex
    #
    # \param[in] mutex thread::mutex handle
    # \param[in] script Code to execute with the mutex
    proc with_mutex {mutex script} {
	thread::mutex lock $mutex
	try {
	    uplevel 1 $script
	} finally {
	    thread::mutex unlock $mutex
	}
    }


    ## Run a script in the context of a read mutex
    #
    # \param[in] mutex thread::rwmutex handle
    # \param[in] script Code to execute with the mutex
    proc with_rmutex {mutex script} {
	thread::rwmutex rlock $mutex
	try {
	    uplevel 1 $script
	} finally {
	    thread::rwmutex unlock $mutex
	}
    }


    ## Run a script in the context of a write mutex
    #
    # \param[in] mutex thread::rwmutex handle
    # \param[in] script Code to execute with the mutex
    proc with_wmutex {mutex script} {
	thread::rwmutex wlock $mutex
	try {
	    uplevel 1 $script
	} finally {
	    thread::rwmutex unlock $mutex
	}
    }


    ## Extract a single option and its value from a line
    #
    # \param[in] opt Option to pull out
    # \param[in] args List of arguments to pull out opt
    # \param[out] _optValue variable to write the opt value if return 1
    # \param[out] _newArgs args after having option removed
    #
    # \returns 1 if the option was found and extracted and 0 otherwise
    proc extract_opt_value {opt args _optValue _newArgs} {
	upvar $_optValue optValue
	upvar $_newArgs newArgs

	if {[set optIndex [lsearch $args $opt]] == -1} {
	    set newArgs $args
	    return 0
	}

	set optValue [lindex $args [expr {$optIndex + 1}]]
	set newArgs [lreplace $args $optIndex [incr optIndex]]
	return 1
    }

    ## Extract a single boolean option from a line
    #
    # \param[in] opt Option to pull out
    # \param[in] args List of arguments to pull out opt
    # \param[out] _optValue variable to write the opt value
    # \param[out] _newArgs args after having option removed
    #
    # \returns 1 if the option was found and extracted and 0 otherwise
    proc extract_opt_boolean {opt args _optValue _newArgs} {
	upvar $_optValue optValue
	upvar $_newArgs newArgs

	if {[set optIndex [lsearch $args $opt]] == -1} {
	    set newArgs $args
	    return [set optValue 0]
	}

	set newArgs [lreplace $args $optIndex $optIndex]
	return [set optValue 1]
    }
}


# vim: set ts=8 sw=4 sts=4 noet :
