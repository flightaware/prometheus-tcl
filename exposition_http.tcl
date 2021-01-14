package provide prometheus-tcl 0.0.1

## \file exposition_http.tcl
#
# Provides the procs used for exposing metrics over HTTP, both pull and push
#
# The pull functionality does the minimum necessary to handle HTTP/1.1 requests
#
# Despite its minimalism, it supports TLS and can send gzip'ed reponses
#
# In general, the HTTP exposition tries to be faithful to the HTTP/1.1 RFCs but
# it does not implement a number of features, e.g., chunked transfer encoding
# that would be required of a full-fledged HTTP server
# Luckily not many features are needed to properly respond to a Prometheus scrape
# so the package's provided exposition works well
#
# As a note on design decisions, httpd could have been used instead of the
# implemention found below but httpd's documentation lacks sufficient examples
# for doing something like this and brings in a plethora of code and features
# not necessary to expose metrics over HTTP
#

package require cmdline
package require zlib

## Pull functionality for exposing Prometheus metrics over HTTP
namespace eval prom::http::pull {
    # Holds the socket for serving Prometheus metrics over HTTP
    variable _sockD [dict create]


    ## Listen on a port and expose Prometheus metrics over HTTP
    #
    # Takes the same arguments as prom::expose
    proc listen {_opts} {
	upvar $_opts opts

	set sockKey "$opts(address):$opts(port)"

	variable _sockD
	if {[dict exists $_sockD $sockKey]} {
	    error "Already listening on $sockKey"
	}

	set socketCommand socket
	if {$opts(tls)} {
	    package require tls
	    set socketCommand tls::socket
	}

	set sock [$socketCommand -server [_server_callback opts] -myaddr $opts(address) $opts(port)]
	dict set _sockD $sockKey $sock
    }


    proc _server_callback {_opts} {
	upvar $_opts opts
	return [list prom::http::pull::accept_callback $opts(path) $opts(timeoutMS)]
    }


    ## Stop listening on a particular address and port
    #
    # Takes the same arguments as prom::unexpose
    #
    # \returns 1 if a server socket is closed or 0 otherwise
    #
    # No error is thrown if not currently listening on the provided address and port
    proc unlisten {_opts} {
	upvar $_opts opts

	set sockKey "$opts(address):$opts(port)"

	variable _sockD
	if {![dict exists $_sockD $sockKey]} {
	    return 0
	}

	set s [dict get $_sockD $sockKey]
	catch {close $s}

	dict unset _sockD $sockKey
	return 1
    }


    ## Server callback for exposing metrics over HTTP
    #
    # \param[in] acceptedPath -path argument passed to listen
    # \param[in] timeoutMS -timeout argument passed to listen
    # \param[in] clientSock client socket for new connection
    # \param[in] args Contains extra args not needed for accepting connections
    proc accept_callback {acceptedPath timeoutMS clientSock args} {
	configure_client_socket $clientSock
	lassign [extract_http_request $clientSock $timeoutMS] startLine requestHeaders

	if {[http_request_accepted $acceptedPath $startLine $requestHeaders errorReason]} {
	    http_reply_ok $clientSock $requestHeaders
	} else {
	    http_reply_not_ok $clientSock $errorReason
	}
    }


    ## Return true if the HTTP request is accepted or 0 otherwise
    #
    # \param[in] acceptedPath -path argument passed to listen
    # \param[in] startLine First line read from the request
    # \param[in] requestHeaders Dict of request headers
    # \param[out] _errorReason Two-element list of {statusCode statusText}. Only set if returns 0
    #
    proc http_request_accepted {acceptedPath startLine requestHeaders _errorReason} {
	upvar $_errorReason errorReason

	if {![valid_request_line $startLine]} {
	    set errorReason {400 {Bad Request}}
	    return 0
	}

	if {[lindex $startLine end] ne "HTTP/1.1"} {
	    set errorReason {505 {HTTP Version Not Supported}}
	    return 0
	}

	if {![dict exists $requestHeaders host]} {
	    set errorReason {400 {Bad Request}}
	    return 0
	}

	if {![valid_request_target $startLine $acceptedPath]} {
	    set errorReason {404 {Not Found}}
	    return 0
	}

	return 1
    }


    ## Configure the client socket passed to the HTTP accept callback
    #
    # Makes the client socket:
    #
    #  - non-blocking
    #  - CRLF input translation
    #  - binary output translation
    #  - full buffering of sends
    #  - maximum buffer size allowed
    #
    # \returns Empty string but modifies clientSock using chan configure
    proc configure_client_socket {clientSock} {
	set configOpts [list]
	lappend configOpts -blocking 0
	lappend configOpts -translation {crlf binary}
	lappend configOpts -buffering full
	lappend configOpts -buffersize [client_socket_buffersize]

	chan configure $clientSock {*}$configOpts
    }


    ## Returns the maximum buffer size for the client HTTP socket
    proc client_socket_buffersize {} {
	return [expr {10**6}]
    }


    ## Return 1 if a newly connected client has sent us data
    #
    # \param[in] clientSock Client socket
    # \param[in] timeoutMS Timeout in milliseconds to wait for data
    #
    # This proc uses the event loop, vwait and a readable chan event
    # callback to wait for data to read on the client socket
    #
    # A timeout is necessary so a client who connects but sends nothing
    # is not allowed to hold the connection open indefinitely
    proc ready_to_read {clientSock timeoutMS} {
	set readableVar prom::http::pull::${clientSock}_readable
	chan event $clientSock readable [list set $readableVar 1]

	set afterID [after $timeoutMS [list set $readableVar 0]]
	vwait $readableVar

	after cancel $afterID
	chan event $clientSock readable ""

	return [set $readableVar]
    }


    ## Extract the start line and request headers from an HTTP request
    #
    # \param[in] clientSock Client socket
    # \param[in] timeoutMS Timeout in milliseconds to wait for data
    #
    # \returns two-element list of {startLine requestHeaders} where startLine is
    #  a three-element list of {method request-target HTTP-version} and requestHeaders
    #  is a dictionary of the headers provided
    proc extract_http_request {clientSock timeoutMS} {
	if {![ready_to_read $clientSock $timeoutMS]} {
	    return
	}

	set startLine ""
	set requestHeaders [dict create]

	while {[chan gets $clientSock line] >= 0} {
	    # Stop processing after a blank line once gotten
	    # a startLine and at least one header
	    if {$line eq ""} {
		if {[valid_blank_line $startLine $requestHeaders]} {
		    break
		} else {
		    return
		}
	    }

	    if {$startLine eq ""} {
		if {![valid_request_line $line]} {
		    break
		}

		set startLine $line
	    } elseif {[valid_header_line $line]} {
		lassign [split $line :] k v

		# RFC7230 says header field names are case-insensitive (3.2)
		dict set requestHeaders [string tolower $k] $v
	    } else {
		# reject any request that is not a valid header
		return
	    }
	}

	return [list $startLine $requestHeaders]
    }

    ## Whether the first line of the HTTP request is valid
    #
    # \param[in] startLine First line read from the HTTP request
    proc valid_request_line {startLine} {
	return [regexp {^GET /\w* HTTP/\d\.\d$} $startLine]
    }


    ## Whether each line read after the first line is a valid HTTP header
    #
    # \param[in] headerLine One of the potential HTTP headers
    proc valid_header_line {headerLine} {
	return [regexp {^[\w-]+: .*$} $headerLine]
    }


    ## Whether the request-target in the first line read matches the -path to listen
    #
    # \param[in] startLine First line read from HTTP request
    # \param[in] acceptedPath Value of -path argument passed to listen
    proc valid_request_target {startLine acceptedPath} {
	# startLine is {method request-target HTTP-method}
	return [expr {[lindex $startLine 1] eq $acceptedPath}]
    }


    ## Whether the first blank line read actually signals the end of the HTTP request
    #
    # \param[in] startLine First line read from HTTP request
    # \param[in] requestHeaders Dictionary of HTTP request headers
    proc valid_blank_line {startLine requestHeaders} {
	# Either a blank line means that the HTTP startLine and headers
	# have all been sent, or that sending stopped abruptly
	#
	# RFC7230 says a client MUST send a Host header (5.4)
	# so if we have that and a startLine, can break
	# Otherwise, want to signal an error happened
	if {$startLine eq ""} {
	    return 0
	}

	if {![dict exists $requestHeaders host]} {
	    return 0
	}

	return 1
    }


    ## Return the HTTP headers to use for 200 reply
    #
    # \param[in] requestHeaders Dict of HTTP request headers
    # \param[in] messageBody Prometheus metrics to reply with
    proc http_reply_ok_headers {requestHeaders messageBody} {
	set replyHeaders [list]

	lappend replyHeaders [header_content_type]
	lappend replyHeaders [header_content_length $messageBody]
	lappend replyHeaders [header_date]
	lappend replyHeaders [header_server]
	if {[gzip_reply $requestHeaders]} {
	    lappend replyHeaders [header_content_encoding gzip]
	}
	lappend replyHeaders [header_connection]

	return [join $replyHeaders "\r\n"]
    }


    ## HTTP response headers to indicate an error
    #
    # \returns a string of the HTTP headers suitable to send on a socket
    proc http_reply_not_ok_headers {} {
	set replyHeaders [list]
	lappend replyHeaders [header_content_length ""]
	lappend replyHeaders [header_connection]

	return [join $replyHeaders "\r\n"]
    }


    ## Return a suitable HTTP response line
    #
    # \param[in] statusCode HTTP status code to send
    # \param[in] reason Textual description of the statusCode
    proc http_start_line {statusCode reason} {
	return "HTTP/1.1 $statusCode $reason"
    }


    ## Whether the HTTP reply should be compressed with gzip
    #
    # \param[in] requestHeader Dict of request headers
    proc gzip_reply {requestHeaders} {
	if {![dict exists $requestHeaders accept-encoding]} {
	    return 0
	}

	set clientEncodings [dict get $requestHeaders accept-encoding]
	return [regexp gzip [string tolower $clientEncodings]]
    }


    ## Send a successful HTTP reply
    #
    # \param[in] clientSock Socket to send the reply over
    # \param[in] requestHeaders Dict of request headers
    #
    # If sending fails no error is raised.
    #
    # After returning, this proc always closes the clientSock
    proc http_reply_ok {clientSock requestHeaders} {
	set startLine [http_start_line 200 OK]

	set messageBody [prom::collect]
	if {[gzip_reply $requestHeaders]} {
	    # zlib command always operates on binary strings
	    set messageBody [encoding convertto utf-8 $messageBody]
	    set messageBody [zlib gzip $messageBody]
	}

	set replyHeaders [http_reply_ok_headers $requestHeaders $messageBody]

	try {
	    chan puts -nonewline $clientSock "$startLine\r\n"
	    chan puts -nonewline $clientSock "$replyHeaders\r\n"
	    chan puts -nonewline $clientSock "\r\n"
	    chan puts -nonewline $clientSock $messageBody
	} on error {} {
	    # ignore errors and move on...
	} finally {
	    # closing the channel causes it to get flushed
	    catch {chan close $clientSock}
	}
    }


    ## Send an HTTP reply for an error in processing
    #
    # \param[in] clientSock Socket to send the reply over
    # \param[in] errorReason Two-element list for the start line
    #
    # If sending fails no error is raised.
    #
    # After returning, this proc always closes the clientSock
    proc http_reply_not_ok {clientSock errorReason} {
	set startLine [http_start_line {*}$errorReason]
	set replyHeaders [http_reply_not_ok_headers]

	try {
	    chan puts -nonewline $clientSock "$startLine\r\n"
	    chan puts -nonewline $clientSock "$replyHeaders\r\n"
	    chan puts -nonewline $clientSock "\r\n"
	} on error {} {
	    # move on quietly after an error...
	} finally {
	    catch {chan close $clientSock}
	}
    }


    ## Return an RFC7231 formatted timestamp
    proc http_date {} {
	clock format [clock seconds] -format {%a, %d %b %Y %H:%M:%S %Z} -gmt 1
    }


    ## Return the full HTTP Date header
    proc header_date {} {
	return "Date: [http_date]"
    }


    ## Return the full HTTP Connection header
    proc header_connection {} {
	return "Connection: closing"
    }


    ## Return the full HTTP Server header
    proc header_server {} {
	set tclVersion [info tclversion]
	set libVersion [package versions prometheus-tcl]
	return "Server: Tcl/${tclVersion} prometheus-tcl/${libVersion}"
    }


    ## Return the full HTTP Content-Type header
    proc header_content_type {} {
	return "Content-Type: [header_content_type_value]"
    }


    ## Return the HTTP Content-Type header's value
    proc header_content_type_value {} {
	return "text/plain; version=0.0.4; charset=utf-8"
    }


    ## Return the full HTTP Content-Encoding header
    proc header_content_encoding {encodingType} {
	return "Content-Encoding: $encodingType"
    }


    ## Return the full HTTP Content-Length header
    proc header_content_length {messageBody} {
	return "Content-Length: [string length $messageBody]"
    }
}; # namespace prom::http::pull


## Push functionality for sending Prometheus metrics over HTTP
# This is for sending metrics to a PushGateway
namespace eval prom::http::push {
    ## Parse common arguments to the prom::*_gateway procs
    #
    # Meant to be a private, internal use only proc
    #
    # \param[in] procPrefix Prefix for the proc name invoking this proc
    # \param[in] args Arguments accepted by prom::*_gateway procs
    #
    # \returns Key value list of options and option values
    proc _gateway_arg_parsing {procPrefix args} {
	set usage "prom::${procPrefix}_to_gateway gateway job ?-groupingKey labelsDict? ?-timeoutMS timeoutMS?"
	set options {
	    {groupingKey.arg "" "Dict of label name and value pairs provided to the gateway as a grouping key"}
	    {timeout.arg 5000 "How long in milliseconds to wait for a gateway connection before giving up"}
	}

	return [::cmdline::getoptions args $options $usage]
    }


    ## Common proc for sending an HTTP request to a PushGateway
    #
    # \param[in] method HTTP method to send to the gateway
    # \param[in] gateway PushGateway hostname
    # \param[in] job Job name for the push
    # \param[in] groupingKey Dict of grouping key label names and values
    # \param[in] timeoutMS Millisecond timeout for sending the HTTP request
    #
    # \returns 1 if a successful status code is returned or 0 otherwise
    #
    # Throws an error if the gateway hostname is invalid
    #
    # Throws an error if any of the groupingKey keys is an invalid label
    proc _gateway_common {method gateway job groupingKey timeoutMS} {
	package require http

	set gatewayURL [_gateway_url $gateway $job $groupingKey uriParts]
	if {$uriParts(scheme) eq "https"} {
	    package require tls
	    ::http::register https $uriParts(port) ::tls::socket
	}

	try {
	    set getURLArgs [list]
	    lappend getURLArgs -method $method
	    lappend getURLArgs -type [prom::http::pull::header_content_type]
	    lappend getURLArgs -query [expr {$method ne "DELETE" ? [prom::collect] : ""}]
	    lappend getURLArgs -timeout $timeoutMS

	    set resp [::http::geturl $gatewayURL {*}$getURLArgs]
	    return [_gateway_success [::http::ncode $resp] $method]
	} finally {
	    catch {::http::cleanup $resp}
	}
    }


    ## Whether the PushGateway response was successful
    #
    # \param[in] statusCode HTTP status code returned
    # \param[in] method HTTP method used for the PushGateway request
    #
    # \returns 1 if success or 0 otherwise
    proc _gateway_success {statusCode method} {
	if {$method eq "PUT"} {
	    return [expr {$statusCode in {200 202}}]
	} elseif {$method eq "POST"} {
	    return [expr {$statusCode == 200}]
	} elseif {$method eq "DELETE"} {
	    return [expr {$statusCode == 202}]
	}
    }


    ## Return the default port for the PushGateway
    proc _gateway_default_port {} {
	return 9091
    }


    ## Return a full fledged PushGateway URL for passing to ::http::geturl
    #
    # \param[in] gateway Gateway hostname passed to prom::*_gateway proc
    # \param[in] job Job name
    # \param[in] groupingKey Dict of label names and values for the grouping key
    # \param[out] _uriParts Populate an array with the result of [uri::split]
    proc _gateway_url {gateway job groupingKey _uriParts} {
	upvar $_uriParts uriParts
	package require uri

	set gateway [string tolower $gateway]
	if {![regexp {^[a-z]+://} $gateway]} {
	    set gateway "http://$gateway"
	}

	try {
	    array set uriParts [uri::split $gateway]
	    if {$uriParts(port) eq ""} {
		append gateway ":[_gateway_default_port]"
	    }
	} on error {} {
	    error "Invalid gateway URI $gateway"
	}

	if {$uriParts(scheme) ni {http https}} {
	    error "Invalid gateway URI scheme: must be http or https"
	}

	set url "${gateway}/metrics"
	append url [_encode_key_value job $job]

	if {![prom::valid_label_keys [dict keys $groupingKey]]} {
	    error "Invalid label value provided in groupingKey dict"
	}

	dict for {labelName labelValue} $groupingKey {
	    append url [_encode_key_value $labelName $labelValue]
	}

	return $url
    }


    ## Encode a key value pair either going in the job name or the grouping key
    #
    # \param[in] k Key to encode
    # \param[in] v Value to encode
    #
    # \returns String of the form /encodedKey/encodedValue
    #
    # If the value contains a /, base64 URL encode it
    # Otherwise, perform usual URI component encoding
    proc _encode_key_value {k v} {
	if {[string first / $v] >= 0} {
	    return [file join / "${k}@base64" [_base64_url_encode $v]]
	} else {
	    package require http
	    return [file join / $k [http::quoteString $v]]
	}
    }


    ## base64URL encode a string
    #
    # \param[in] s String to base64URL encode
    proc _base64_url_encode {s} {
	package require base64
	return [string map {+ - / _ = ""} [base64::encode $s]]
    }
}; # namespace prom::http::pull

# vim: set ts=8 sw=4 sts=4 noet :
