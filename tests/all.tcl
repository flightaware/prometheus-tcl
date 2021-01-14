#!/usr/bin/env tclsh

package require tcltest
namespace import ::tcltest::*

configure -testdir [file dirname [info script]]
runAllTests
