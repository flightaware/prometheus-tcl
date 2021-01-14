#!/usr/bin/env tclsh


proc package_name {} {
    set sourceFile [lindex $::argv 0]
    return [lindex [exec grep "package provide" $sourceFile] 2]
}

proc package_version {} {
    set sourceFile [lindex $::argv 0]
    return [lindex [exec grep "package provide" $sourceFile] end]
}

proc single_file_include {fname} {
    return [format {[list source [file join $dir %s]]} $fname]
}

set startLine "package ifneeded [package_name] [package_version]"
set rest [lmap fname $::argv {single_file_include $fname}]
puts "$startLine [join $rest \\n]"
