## \file metric_test_creators.test
#
# Contains procs for creating unit tests for the different Prometheus
# metric types
#
# Using a proc to create tests cleans up some of the boilerplate needed
# to define a tcltest test case

## Creates a test that checks the return value for a Prometheus metric type
proc metric_result_test {metricType metricName labelsDict ops expectedResult args} {
    set outputCheck [list -match glob -result [string trimleft $expectedResult]]
    return [metric_test_common $metricType $metricName $labelsDict $ops $outputCheck {*}$args]
}

## Creates a test that checks for an error result from a Prometheus metric operation
proc metric_error_test {metricType metricName labelsDict ops {expectedError .*} args} {
    set outputCheck [list -match regexp -returnCodes {error} -result [string trimleft $expectedError]]
    return [metric_test_common $metricType $metricName $labelsDict $ops $outputCheck {*}$args]
}

proc metric_test_common {metricType metricName labelsDict ops outputCheck args} {
    set testName ${metricType}_test_${metricName}
    set testHelp "Testing result of '$ops' on $metricType $metricName"

    set formatArgs [list]
    lappend formatArgs $metricType
    lappend formatArgs $metricName
    lappend formatArgs [concat [list [dict keys $labelsDict]] $args]
    lappend formatArgs $ops
    lappend formatArgs $metricType
    lappend formatArgs $metricName
    lappend formatArgs [dict values $labelsDict]

    test $testName $testHelp -body [format {
        prom::%s::new %s -labels %s

	foreach op {%s} {
	    set method [lindex $op 0]
	    set methodArgs [lrange $op 1 end]
	    prom::%s::$method %s {*}$methodArgs %s
	}

	return [prom::collect]
    } {*}$formatArgs] -cleanup [subst {
        [prom::get_default_registry] unregisterName $metricName
        [prom::get_default_registry] unregisterName ${metricName}_info
    }] {*}$outputCheck
}

## Creates a test for arbitrary combinations of label values for a given metric
proc metric_result_test_family {metricType metricName labelKeys ops expectedResult args} {
    set testName ${metricType}_test_${metricName}
    set testHelp "Testing result of '$ops' on $metricType $metricName"

    set formatArgs [list]
    lappend formatArgs $metricType
    lappend formatArgs $metricName
    lappend formatArgs [concat [list $labelKeys] $args]
    lappend formatArgs $ops
    lappend formatArgs $metricType
    lappend formatArgs $metricName

    test $testName $testHelp -body [format {
	prom::%s::new %s -labels %s

	foreach op {%s} {
	    set method [lindex $op 0]
	    set methodArgs [lrange $op 1 end]
	    prom::%s::$method %s {*}$methodArgs
	}

	return [prom::collect]
    } {*}$formatArgs] -match glob -result [string trimleft $expectedResult] -cleanup {
        [prom::get_default_registry] unregisterName $metricName
        [prom::get_default_registry] unregisterName ${metricName}_info
    }
}

## Return a string glob pattern for detecting some number of digits in a test result
proc timestamp_glob {numDigits} {
    return [join [lrepeat $numDigits {[0-9]}] ""]
}

proc test_return {procName procArgs expectedResult} {
    test ${procName}_return_test [subst {
        Verify the return result of calling
        $procName $procArgs
    }] -body [format {
        return [%s %s]
    } $procName $procArgs] -result [string trimleft $expectedResult]
}

proc test_error {procName procArgs} {
    test ${procName}_return_test [subst {
        Verify an error occurs when calling
        $procName $procArgs
    }] -body [format {
        return [%s %s]
    } $procName $procArgs] -returnCodes {error} -match regexp -result .*
}
